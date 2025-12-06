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
        .onChange(of: routines) { _, _ in
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
        
        // Find next pending bookmark
        let pendingBookmarks = bookmarks
            .filter { $0.status == .ready || $0.status == .pending }
            .sorted { $0.scheduledFor < $1.scheduledFor }
        
        guard let bookmarkToSnooze = pendingBookmarks.first else {
            print("⏰ Siri snooze: No bookmark to snooze")
            return
        }
        
        // Find next routine time
        let nextRoutineDate = findNextRoutineDate()
        
        // Update bookmark's scheduled time
        bookmarkToSnooze.scheduledFor = nextRoutineDate
        
        do {
            try modelContext.save()
            print("⏰ Siri snooze: \(bookmarkToSnooze.title) → \(nextRoutineDate)")
            
            // Update widget data
            WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
        } catch {
            print("❌ Siri snooze error: \(error)")
        }
    }
    
    private func findNextRoutineDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get enabled routines sorted by time
        let enabledRoutines = routines.filter { $0.isEnabled }.sorted { routine1, routine2 in
            let time1 = routine1.hour * 60 + routine1.minute
            let time2 = routine2.hour * 60 + routine2.minute
            return time1 < time2
        }
        
        guard !enabledRoutines.isEmpty else {
            // No routines, snooze to tomorrow same time
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        
        // Find next routine today or future days
        for dayOffset in 0..<8 {
            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let targetWeekday = calendar.component(.weekday, from: targetDate)
            
            for routine in enabledRoutines {
                // Check if routine is enabled for this day
                guard routine.days.contains(targetWeekday) else { continue }
                
                let routineTimeMinutes = routine.hour * 60 + routine.minute
                
                // If today, routine must be in the future
                if dayOffset == 0 && routineTimeMinutes <= currentTimeMinutes {
                    continue
                }
                
                // Found next routine
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = routine.hour
                components.minute = routine.minute
                
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
        case library = "tab.library"
        case pulse = "tab.pulse"
        
        var displayName: String {
            rawValue.localized
        }
        
        var icon: String {
            switch self {
            case .focus: return "bolt.fill"
            case .library: return "books.vertical.fill"
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
                case .library:
                    LibraryView()
                case .pulse:
                    PulseView()
                }
            }
            .tint(Color.joltYellow)
        } else {
            // iPhone: Tab Bar
            TabView(selection: $selectedTab) {
                FocusView()
                    .tabItem {
                        Label(AppTab.focus.displayName, systemImage: AppTab.focus.icon)
                    }
                    .tag(AppTab.focus)
                
                LibraryView()
                    .tabItem {
                        Label(AppTab.library.displayName, systemImage: AppTab.library.icon)
                    }
                    .tag(AppTab.library)
                
                PulseView()
                    .tabItem {
                        Label(AppTab.pulse.displayName, systemImage: AppTab.pulse.icon)
                    }
                    .tag(AppTab.pulse)
            }
            .tint(Color.joltYellow)
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Bookmark.self, inMemory: true)
}
