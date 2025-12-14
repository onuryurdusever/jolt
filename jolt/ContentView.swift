//
//  ContentView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var routines: [Routine]
    @Query private var bookmarks: [Bookmark]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var syncService = SyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(syncService)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Auto-sync on app launch
            if hasCompletedOnboarding {
                await performAutoSync()
                // Update widget data on launch
                await MainActor.run {
                    WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
                }
                // Note: Notification scheduling triggered by scenePhase .active
                // Check for Siri snooze request
                handleSiriSnoozeRequest()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Auto-sync when app comes to foreground
            if newPhase == .active && hasCompletedOnboarding {
                Task {
                    await performAutoSync()
                    // Update widget data when app becomes active
                    await MainActor.run {
                        WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
                    }
                    // Refresh notifications when app becomes active (single trigger point)
                    NotificationCenter.default.post(name: .routinesDidChange, object: nil)
                    // Check for Siri snooze request
                    handleSiriSnoozeRequest()
                }
            }
            
            // Update widgets when app goes to background
            if newPhase == .background && hasCompletedOnboarding {
                WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
            }
        }
        .onChange(of: networkMonitor.isOnline) { wasOnline, isOnline in
            // Process offline actions when internet restored
            if !wasOnline && isOnline && hasCompletedOnboarding {
                print("🌐 Internet restored! Processing offline actions...")
                Task {
                    await syncService.processPendingOfflineActions(context: modelContext)
                    await syncService.syncPendingBookmarks(context: modelContext)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinesDidChange)) { _ in
            // Centralized notification scheduling - single point of entry
            NotificationManager.shared.scheduleSmartNotifications(modelContext: modelContext)
        }
    }
    
    private func performAutoSync() async {
        print("🔄 Auto-sync triggered")
        await syncService.syncPendingBookmarks(context: modelContext)
    }
    
    // MARK: - Siri Snooze Handler
    
    private func handleSiriSnoozeRequest() {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        // Check if there's a pending snooze request
        guard defaults?.bool(forKey: "siri_snooze_request") == true else { return }
        
        // Clear the request immediately
        defaults?.removeObject(forKey: "siri_snooze_request")
        defaults?.removeObject(forKey: "siri_snooze_request_time")
        
        // Find next active bookmark (v2.1)
        let pendingBookmarks = bookmarks
            .filter { $0.status == .active }
            .sorted { $0.scheduledFor < $1.scheduledFor }
        
        guard let bookmarkToSnooze = pendingBookmarks.first else {
            print("⏰ Siri snooze: No bookmark to snooze")
            return
        }
        
        // Find next delivery time
        let nextDeliveryDate = findNextDeliveryDate()
        
        // Update bookmark's scheduled time
        bookmarkToSnooze.scheduledFor = nextDeliveryDate
        
        do {
            try modelContext.save()
            print("⏰ Siri snooze: \(bookmarkToSnooze.title) → \(nextDeliveryDate)")
            
            // Update widget data
            WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
        } catch {
            print("❌ Siri snooze error: \(error)")
        }
    }
    
    private func findNextDeliveryDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get enabled deliveries sorted by time
        let enabledDeliveries = routines.filter { $0.isEnabled }.sorted { delivery1, delivery2 in
            let time1 = delivery1.hour * 60 + delivery1.minute
            let time2 = delivery2.hour * 60 + delivery2.minute
            return time1 < time2
        }
        
        guard !enabledDeliveries.isEmpty else {
            // No deliveries, snooze to tomorrow same time
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        
        // Find next delivery today or future days
        for dayOffset in 0..<8 {
            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let targetWeekday = calendar.component(.weekday, from: targetDate)
            
            for delivery in enabledDeliveries {
                // Check if delivery is enabled for this day
                guard delivery.days.contains(targetWeekday) else { continue }
                
                let deliveryTimeMinutes = delivery.hour * 60 + delivery.minute
                
                // If today, delivery must be in the future
                if dayOffset == 0 && deliveryTimeMinutes <= currentTimeMinutes {
                    continue
                }
                
                // Found next delivery
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = delivery.hour
                components.minute = delivery.minute
                
                if let nextDate = calendar.date(from: components) {
                    return nextDate
                }
            }
        }
        
        // Fallback: tomorrow same time
        return calendar.date(byAdding: .day, value: 1, to: now) ?? now
    }
}

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .focus
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    
    enum AppTab: String, CaseIterable {
        case focus = "tab.focus"
        case history = "tab.history"
        case pulse = "tab.pulse"
        
        var displayName: String {
            rawValue.localized
        }
        
        var icon: String {
            switch self {
            case .focus: return "bolt.fill"
            case .history: return "clock.arrow.circlepath"
            case .pulse: return "waveform.path.ecg"
            }
        }
    }
    
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Sidebar Navigation
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Sidebar
                List {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Label(tab.displayName, systemImage: tab.icon)
                        }
                        .listRowBackground(selectedTab == tab ? Color.joltYellow.opacity(0.2) : Color.clear)
                    }
                }
                .navigationTitle("Jolt")
                .listStyle(.sidebar)
            } detail: {
                // Detail View based on selection
                switch selectedTab {
                case .focus:
                    FocusView()
                case .history:
                    HistoryView()
                case .pulse:
                    PulseView()
                }
            }
            .tint(Color.joltYellow)
        } else {
            // iPhone: Tab Bar with swipe gesture
            TabView(selection: $selectedTab) {
                FocusView()
                    .tabItem {
                        Label(AppTab.focus.displayName, systemImage: AppTab.focus.icon)
                    }
                    .tag(AppTab.focus)
                
                HistoryView()
                    .tabItem {
                        Label(AppTab.history.displayName, systemImage: AppTab.history.icon)
                    }
                    .tag(AppTab.history)
                
                PulseView()
                    .tabItem {
                        Label(AppTab.pulse.displayName, systemImage: AppTab.pulse.icon)
                    }
                    .tag(AppTab.pulse)
            }
            .tint(Color.joltYellow)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        let tabs = AppTab.allCases
                        guard let currentIndex = tabs.firstIndex(of: selectedTab) else { return }
                        
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if horizontalAmount < 0 {
                                // Swipe left - next tab
                                if currentIndex < tabs.count - 1 {
                                    selectedTab = tabs[currentIndex + 1]
                                }
                            } else {
                                // Swipe right - previous tab
                                if currentIndex > 0 {
                                    selectedTab = tabs[currentIndex - 1]
                                }
                            }
                        }
                    }
            )
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Bookmark.self, inMemory: true)
}
