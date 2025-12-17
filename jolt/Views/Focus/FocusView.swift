//
//  FocusView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//  v2.1 - Original design with Expiration Engine logic
//

import SwiftUI
import SwiftData
import Combine

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var enrichmentService = EnrichmentService.shared
    @Query private var allBookmarks: [Bookmark]
    @Query private var allRoutines: [Routine]

    
    // Timer for refreshing "now" - triggers view update every 30 seconds
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var currentTime = Date()
    
    // UI State
    @State private var selectedBookmark: Bookmark?
    @State private var showFilterSheet = false
    @State private var showQuickAdd = false
    @State private var clipboardURL: String = ""
    @State private var isLaterExpanded = false
    
    // Filter State
    @State private var selectedFilter: DurationFilter = .all
    
    // Toast State
    @State private var showToast = false
    @State private var toastType: ClipboardToastType = .new
    @State private var toastURL = ""
    @State private var foundBookmark: Bookmark?
    
    // Long Press Context Menu
    @State private var showSnoozeOptions = false
    @State private var bookmarkToSnooze: Bookmark?
    
    #if DEBUG
    @State private var showDebugMenu = false
    #endif
    
    // Add Link Action Sheet
    @State private var showAddLinkOptions = false
    
    // MARK: - Filter Enum
    
    enum DurationFilter: String, CaseIterable {
        case five = "focus.filter.5min"
        case fifteen = "focus.filter.15min"
        case all = "focus.filter.all"
        
        var displayName: String {
            switch self {
            case .five: return "focus.filter.5min".localized
            case .fifteen: return "focus.filter.15min".localized
            case .all: return "focus.filter.all".localized
            }
        }
        
        var maxMinutes: Int? {
            switch self {
            case .five: return 5
            case .fifteen: return 15
            case .all: return nil
            }
        }
        
        var icon: String {
            switch self {
            case .five: return "hare"
            case .fifteen: return "tortoise"
            case .all: return "infinity"
            }
        }
    }
    
    // MARK: - Computed Properties (v2.1 Updated)
    
    private var activeBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .active }
    }
    
    private var readyBookmarks: [Bookmark] {
        let now = currentTime
        // v2.1: Sort by expiresAt (closest to expiring first)
        return activeBookmarks
            .filter { $0.scheduledFor <= now }
            .sorted { b1, b2 in
                // En yakın expire eden üstte
                let exp1 = b1.expiresAt ?? Date.distantFuture
                let exp2 = b2.expiresAt ?? Date.distantFuture
                return exp1 < exp2
            }
    }
    
    private var filteredBookmarks: [Bookmark] {
        guard let maxMinutes = selectedFilter.maxMinutes else { return readyBookmarks }
        return readyBookmarks.filter { $0.readingTimeMinutes <= maxMinutes }
    }
    
    private var upcomingBookmarks: [Bookmark] {
        let now = currentTime
        return activeBookmarks
            .filter { $0.scheduledFor > now }
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    // v2.1: Dying soon bookmarks (urgent or critical)
    private var dyingSoonCount: Int {
        readyBookmarks.filter { $0.expirationUrgency == .urgent || $0.expirationUrgency == .critical }.count
    }
    
    private var totalReadingTime: Int {
        filteredBookmarks.reduce(0) { $0 + $1.readingTimeMinutes }
    }
    
    // v2.1: Show all bookmarks (no more +5 daha hiding)
    private var visibleBookmarks: [Bookmark] {
        return filteredBookmarks
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Minimal Header
                    minimalHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    if filteredBookmarks.isEmpty && upcomingBookmarks.isEmpty {
                        // Breathing Empty State - truly empty
                        breathingEmptyState
                            .frame(maxHeight: .infinity)
                    } else if filteredBookmarks.isEmpty {
                        // No ready bookmarks but have upcoming - show empty state + later section
                        ScrollView {
                            VStack(spacing: 0) {
                                // Empty state - centered in upper portion
                                breathingEmptyState
                                    .frame(minHeight: 280)
                                    .frame(maxWidth: .infinity)
                                
                                // Flexible spacer pushes "Sonra" to bottom
                                Spacer(minLength: 40)
                                
                                // v2.1 DOZ: "Sonra" bölümü - planlanmış içerikler
                                if !upcomingBookmarks.isEmpty {
                                    laterSection
                                        .padding(.horizontal, 20)
                                        .fixedSize(horizontal: false, vertical: true) // Prevent vertical stretching
                                }
                            }
                            .frame(minHeight: UIScreen.main.bounds.height - 250)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await enrichmentService.processPendingEnrichments(context: modelContext)
                        }
                    } else {
                        // Content - Using List for swipe actions support
                        List {
                            // v2.1: Dying Soon Alert
                            if dyingSoonCount > 0 {
                                dyingSoonAlert
                                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            
                            // FOCUS Section Header
                            focusSectionHeader
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            
                            // Hero Card (First Item)
                            if let heroBookmark = filteredBookmarks.first {
                                HeroFocusCard(
                                    bookmark: heroBookmark,
                                    onTap: { selectedBookmark = heroBookmark },
                                    onArchive: { completeBookmark(heroBookmark) },
                                    onSnooze: { snoozeToNextDelivery(heroBookmark) },
                                    onBurn: { burnBookmark(heroBookmark) }
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            
                            // Ultra-Compact Rows (Rest) with fade effect after 50%
                            ForEach(Array(visibleBookmarks.dropFirst().enumerated()), id: \.element.id) { index, bookmark in
                                let totalItems = visibleBookmarks.count
                                let actualIndex = index + 1 // +1 because we dropped first
                                let fadeStartIndex = totalItems / 2
                                let opacity = actualIndex >= fadeStartIndex ? 
                                    max(0.3, 1.0 - Double(actualIndex - fadeStartIndex) / Double(max(1, totalItems - fadeStartIndex)) * 0.7) : 1.0
                                
                                UltraCompactRow(
                                    bookmark: bookmark,
                                    onTap: { selectedBookmark = bookmark },
                                    onArchive: { completeBookmark(bookmark) },
                                    onSnooze: { snoozeToNextDelivery(bookmark) },
                                    onBurn: { burnBookmark(bookmark) }
                                )
                                .opacity(opacity)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            
                            // v2.1 DOZ: "Sonra" bölümü - planlanmış içerikler
                            if !upcomingBookmarks.isEmpty {
                                laterSection
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await enrichmentService.processPendingEnrichments(context: modelContext)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedBookmark) { bookmark in
                ReaderView(bookmark: bookmark, onJoltCompleted: { joltedBookmark in
                    handleJoltCompletion(for: joltedBookmark)
                })
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(url: clipboardURL, modelContext: modelContext)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog("snooze.title".localized, isPresented: $showSnoozeOptions, presenting: bookmarkToSnooze) { bookmark in
                Button("snooze.nextDelivery".localized) { snoozeToNextDelivery(bookmark) }
                Button("snooze.1hour".localized) { snoozeBookmark(bookmark, hours: 1) }
                Button("snooze.2hours".localized) { snoozeBookmark(bookmark, hours: 3) }
                Button("snooze.tomorrow".localized) { snoozeToTomorrowMorning(bookmark) }
                Button("common.cancel".localized, role: .cancel) { }
            }
            #if DEBUG
            .confirmationDialog("focus.debug.title".localized, isPresented: $showDebugMenu) {
                Button("focus.debug.addTestData".localized) { generateTestData() }
                Button("focus.debug.clearAll".localized, role: .destructive) { clearAllBookmarks() }
                Button("common.cancel".localized, role: .cancel) { }
            }
            #endif
            .confirmationDialog("focus.addLink.title".localized, isPresented: $showAddLinkOptions) {
                Button("focus.addLink.paste".localized) {
                    checkClipboardAndOpen()
                }
                Button("focus.addLink.howTo".localized) {
                    showShareSheetInstructions()
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("focus.addLink.message".localized)
            }
            .clipboardToast(isPresented: $showToast, url: toastURL, type: toastType) {
                handleToastAction()
            }
            .onAppear {
                currentTime = Date()
                // v2.1: Process expired bookmarks on appear
                ExpirationService.shared.processExpiredBookmarks(modelContext: modelContext)
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }
    
    // MARK: - v2.1 Dying Soon Alert
    
    private var dyingSoonAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text("focus.dyingSoon".localized(with: dyingSoonCount))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.orange)
            
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
    }
    
    // MARK: - Minimal Header
    
    private var minimalHeader: some View {
        HStack(alignment: .center) {
            // Left: Stats (Tappable for filter)
            Button {
                showFilterSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.joltYellow)
                    
                    if filteredBookmarks.isEmpty {
                        Text("focus.allCaughtUp".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.joltForeground)
                    } else {
                        Text("focus.articles.count".localized(with: filteredBookmarks.count))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.joltForeground)
                        
                        Text("•")
                            .foregroundColor(.joltMutedForeground)
                        
                        Text("focus.totalTime".localized(with: totalReadingTime))
                            .font(.system(size: 15))
                            .foregroundColor(.joltMutedForeground)
                    }
                    
                    // Filter indicator
                    if selectedFilter != .all {
                        Image(systemName: selectedFilter.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.joltYellow)
                            .padding(.leading, 4)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(A11y.Focus.headerStats(count: filteredBookmarks.count, totalMinutes: totalReadingTime))
            .accessibilityHint(A11y.Focus.filterButton(current: selectedFilter.rawValue))
            .accessibilityAddTraits(.isButton)
            
            Spacer()
            
            // Right: Action buttons
            HStack(spacing: 16) {
                #if DEBUG
                Button {
                    showDebugMenu = true
                } label: {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("a11y.focus.debugMenu".localized)
                #endif
                
                // Add Link Button
                Button {
                    showAddLinkOptions = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.joltYellow)
                }
                .accessibilityLabel("a11y.focus.addLink".localized)
                .accessibilityHint("a11y.focus.addLinkHint".localized)
            }
        }
    }
    
    // MARK: - Focus Section Header
    
    private var focusSectionHeader: some View {
        HStack {
            Text("focus.title".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.joltMutedForeground)
            
            Text("(\(filteredBookmarks.count))")
                .font(.system(size: 14))
                .foregroundColor(.joltMutedForeground.opacity(0.7))
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Later Section (Collapsed)
    
    private var laterSection: some View {
        Group {
            // Header button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isLaterExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("focus.later".localized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                    
                    Text("(\(upcomingBookmarks.count))")
                        .font(.system(size: 14))
                        .foregroundColor(.joltMutedForeground.opacity(0.7))
                    
                    Spacer()
                    
                    Image(systemName: isLaterExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                }
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            
            if isLaterExpanded {
                ForEach(upcomingBookmarks) { bookmark in
                    UltraCompactRow(
                        bookmark: bookmark,
                        isUpcoming: true,
                        onTap: { pullForward(bookmark) },
                        onArchive: { completeBookmark(bookmark) },
                        onSnooze: { },
                        onBurn: { burnBookmark(bookmark) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            List {
                ForEach(DurationFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                        showFilterSheet = false
                    } label: {
                        HStack {
                            Image(systemName: filter.icon)
                                .foregroundColor(filter == selectedFilter ? .joltYellow : .joltMutedForeground)
                                .frame(width: 24)
                            
                            Text(filter.displayName)
                                .foregroundColor(.joltForeground)
                            
                            Spacer()
                            
                            if filter == selectedFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.joltYellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("focus.filter.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        showFilterSheet = false
                    }
                    .foregroundColor(.joltYellow)
                }
            }
        }
        .presentationDetents([.height(250)])
    }
    
    // MARK: - Breathing Empty State
    
    private var breathingEmptyState: some View {
        BreathingEmptyState()
    }
    
    // MARK: - Actions (v2.1 Updated)
    
    /// v2.1: Mark bookmark as completed (was archiveBookmark)
    private func completeBookmark(_ bookmark: Bookmark) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("👆 USER ACTION: Completing \(bookmark.title)")
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.markCompleted()
        }
        try? modelContext.save()
        
        // Show undo toast
        foundBookmark = bookmark
        toastURL = bookmark.originalURL
        toastType = .undo
        showToast = true
        
        // Auto-hide toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.toastType == .undo && self.showToast && self.foundBookmark?.id == bookmark.id {
                withAnimation { self.showToast = false }
            }
        }
    }
    
    /// v2.1: Archive bookmark manually (skip without completing)
    private func archiveBookmark(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.archiveManually()
        }
        try? modelContext.save()
    }
    
    /// v2.1: Burn bookmark - move to burnt/expired status
    private func burnBookmark(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.burn()
        }
        try? modelContext.save()
        
        // Update widgets
        WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
    }
    
    private func snoozeToNextDelivery(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        let nextDeliveryTime = calculateNextDeliveryTime()
        
        // v2.1: Track snooze count
        let isPremium = UserDefaults.standard.bool(forKey: "isPremium")
        bookmark.snooze(to: .tomorrow, isPremium: isPremium)
        bookmark.scheduledFor = nextDeliveryTime
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            // Animation trigger
        }
        try? modelContext.save()
    }
    
    private func snoozeBookmark(_ bookmark: Bookmark, hours: Int) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        let isPremium = UserDefaults.standard.bool(forKey: "isPremium")
        bookmark.snooze(to: .tomorrow, isPremium: isPremium)
        bookmark.scheduledFor = Date().addingTimeInterval(TimeInterval(hours * 3600))
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            // Animation trigger
        }
        try? modelContext.save()
    }
    
    private func snoozeToTomorrowMorning(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 9
        components.minute = 0
        
        if let tomorrowMorning = calendar.date(from: components) {
            let isPremium = UserDefaults.standard.bool(forKey: "isPremium")
            bookmark.snooze(to: .tomorrow, isPremium: isPremium)
            bookmark.scheduledFor = tomorrowMorning
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                // Animation trigger
            }
            try? modelContext.save()
        }
    }
    
    private func calculateNextDeliveryTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        let enabledDeliveries = allRoutines
            .filter { $0.isEnabled }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        
        guard !enabledDeliveries.isEmpty else {
            return now.addingTimeInterval(3 * 3600)
        }
        
        for delivery in enabledDeliveries {
            let deliveryMinutes = delivery.hour * 60 + delivery.minute
            let currentMinutes = currentHour * 60 + currentMinute
            
            if deliveryMinutes > currentMinutes && delivery.days.contains(currentWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = delivery.hour
                components.minute = delivery.minute
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let futureWeekday = calendar.component(.weekday, from: futureDate)
            
            for delivery in enabledDeliveries {
                if delivery.days.contains(futureWeekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
                    components.hour = delivery.hour
                    components.minute = delivery.minute
                    if let date = calendar.date(from: components) {
                        return date
                    }
                }
            }
        }
        
        return now.addingTimeInterval(24 * 3600)
    }
    
    private func pullForward(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        bookmark.scheduledFor = Date()
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentTime = Date()
        }
    }
    
    private func handleJoltCompletion(for bookmark: Bookmark) {
        selectedBookmark = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            completeBookmark(bookmark)
        }
    }
    
    private func checkClipboardAndOpen() {
        guard let string = UIPasteboard.general.string,
              let url = URL(string: string),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return
        }
        
        clipboardURL = string
        
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.originalURL == string })
        if let existing = try? modelContext.fetch(descriptor).first {
            foundBookmark = existing
            toastURL = string
            toastType = existing.status == .archived ? .existingArchived : .existingUnread
            showToast = true
        } else {
            showQuickAdd = true
        }
    }
    
    private func handleToastAction() {
        if toastType == .undo {
            if let bookmark = foundBookmark {
                withAnimation {
                    bookmark.status = .active
                    bookmark.readAt = nil
                    bookmark.archivedAt = nil
                    bookmark.archivedReason = nil
                }
                try? modelContext.save()
            }
        } else if toastType == .existingUnread || toastType == .existingArchived {
            if let bookmark = foundBookmark {
                selectedBookmark = bookmark
            }
        }
        showToast = false
    }
    
    private func showShareSheetInstructions() {
        // Open Safari to show how to use share extension
        if let url = URL(string: "https://www.apple.com") {
            UIApplication.shared.open(url)
        }
    }
    
    #if DEBUG
    private func generateTestData() {
        // Clear existing data first
        clearAllBookmarks()
        

        
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 🔥 Burned (Expired) - For Stats & Pulse Health
        let expiredItems = [
            ("Eski Teknoloji Haberleri", "techcrunch.com", 5, -2, BookmarkType.article),
            ("Geçen Haftanın Özeti", "medium.com", 12, -5, BookmarkType.article),
            ("Artık Önemsiz Bir Makale", "random.org", 3, -10, BookmarkType.article)
        ]
        
        for (title, domain, minutes, daysAgo, type) in expiredItems {
            let scheduled = calendar.date(byAdding: .day, value: daysAgo - 7, to: now)!
            let expires = calendar.date(byAdding: .day, value: daysAgo, to: now)!
            
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://\(domain)/\(UUID().uuidString)",
                status: .expired,
                scheduledFor: scheduled,
                title: title,
                readingTimeMinutes: minutes,
                type: type,
                domain: domain,
                expiresAt: expires,
                intent: .now
            )

            modelContext.insert(bookmark)
        }
        
        // 2. 💀 Critical (Dying Soon) - For Alerts & Urgency UI
        let criticalItems = [
            ("ACİL: Bu Gece Silinecek", "deadline.com", 8, 0.5, BookmarkType.article), // 12 hours left
            ("Son Şans: Yarın Sabah Gidiyor", "lastchance.io", 15, 0.9, BookmarkType.video) // 21 hours left
        ]
        
        for (title, domain, minutes, daysLeft, type) in criticalItems {
            let scheduled = calendar.date(byAdding: .day, value: -6, to: now)!
            let expires = calendar.date(byAdding: .hour, value: Int(daysLeft * 24), to: now)!
            
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://\(domain)/\(UUID().uuidString)",
                status: .active,
                scheduledFor: scheduled,
                title: title,
                readingTimeMinutes: minutes,
                type: type,
                domain: domain,
                expiresAt: expires,
                intent: .now
            )

            modelContext.insert(bookmark)
        }
        
        // 3. ⚡️ Ready (Focus Now) - Hybrid Content
        let readyItems = [
            ("Swift 6 Concurrency", "swift.org", 12, 5.0, BookmarkType.article),
            ("iOS 18 Design Kit (PDF)", "apple.com", 25, 6.0, BookmarkType.pdf),
            ("WWDC24 Recap Video", "youtube.com", 45, 4.0, BookmarkType.video),
            ("Twitter Thread: AI Tools", "x.com", 3, 3.0, BookmarkType.social),
            ("Best Coffee Shops", "maps.google.com", 2, 6.5, BookmarkType.map)
        ]
        
        for (title, domain, minutes, daysLeft, type) in readyItems {
            let scheduled = calendar.date(byAdding: .hour, value: -1, to: now)! // Scheduled 1 hour ago
            let expires = calendar.date(byAdding: .day, value: Int(daysLeft), to: now)!
            
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://\(domain)/\(UUID().uuidString)",
                status: .active,
                scheduledFor: scheduled,
                title: title,
                readingTimeMinutes: minutes,
                type: type,
                domain: domain,
                expiresAt: expires,
                intent: .now
            )
            
            // Randomly assign metadata for Video/Social
            if type == .video {
                bookmark.metadata = ["duration_iso": "PT45M", "author_name": "Apple"]
            } else if type == .social {
                bookmark.metadata = ["author_handle": "@tech_guru", "author_name": "Tech Guru"]
            }
            

            modelContext.insert(bookmark)
        }
        
        // 4. 📅 Future (Scheduled) - For Filter Testing
        // Tomorrow Morning
        if let tomorrowVal = calendar.date(byAdding: .day, value: 1, to: now) {
            let tomorrow = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrowVal)!
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://future.com/tomorrow",
                status: .active,
                scheduledFor: tomorrow,
                title: "Yarın Sabah Okunacak",
                readingTimeMinutes: 10,
                type: .article,
                domain: "future.com",
                expiresAt: calendar.date(byAdding: .day, value: 8, to: now),
                intent: .tomorrow
            )
            modelContext.insert(bookmark)
        }
        
        // Weekend
        if let nextSat = calendar.nextWeekend(startingAfter: now)?.start {
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://weekend.read/deep-dive",
                status: .active,
                scheduledFor: nextSat,
                title: "Hafta Sonu Keyfi",
                readingTimeMinutes: 60,
                type: .article,
                domain: "weekend.read",
                expiresAt: calendar.date(byAdding: .day, value: 14, to: now),
                intent: .weekend
            )
            modelContext.insert(bookmark)
        }
        
        // 5. ✅ Completed (Archive) - For Streak & Pulse Stats
        let completedItems = [
            ("Okunmuş Makale 1", "read.com", 5, -1),
            ("Bitmiş Video", "youtube.com", 15, -1),
            ("Eski Haber", "news.com", 3, -2),
            ("Derin Analiz", "analytics.io", 20, -3),
            ("Hızlı İpucu", "tips.net", 2, -4)
        ]
        
        for (title, domain, minutes, daysAgo) in completedItems {
            let readDate = calendar.date(byAdding: .day, value: daysAgo, to: now)!
            let bookmark = Bookmark(
                userID: "test_user",
                originalURL: "https://\(domain)/\(UUID().uuidString)",
                status: .archived, // or .completed based on model logic
                scheduledFor: readDate,
                title: title,
                readingTimeMinutes: minutes,
                type: .article,
                domain: domain,
                expiresAt: calendar.date(byAdding: .day, value: 7, to: readDate),
                intent: .now
            )
            bookmark.readAt = readDate
            bookmark.archivedAt = readDate
            bookmark.archivedReason = "completed"
            bookmark.status = .completed // Explicitly set if enum supports it
            modelContext.insert(bookmark)
        }
        
        // 6. 🧪 Test - Expires in 2 Minutes
        let testExpiryItems = [
            ("TEST: 2 Dakika Süresi Var ⏱️", "test.expire", 2, 2.0),
            ("TEST: Çok Yakında Yanacak 🔥", "test.burn", 5, 2.0)
        ]
        
        for (title, domain, minutes, minutesLeft) in testExpiryItems {
             let scheduled = calendar.date(byAdding: .hour, value: -1, to: now)!
             let expires = calendar.date(byAdding: .minute, value: Int(minutesLeft), to: now)!
             
             let bookmark = Bookmark(
                 userID: "test_user",
                 originalURL: "https://\(domain)/\(UUID().uuidString)",
                 status: .active,
                 scheduledFor: scheduled,
                 title: title,
                 readingTimeMinutes: minutes,
                 type: .article,
                 domain: domain,
                 expiresAt: expires,
                 intent: .now
             )
             modelContext.insert(bookmark)
        }
        
        try? modelContext.save()
        
        // Update Widgets
        WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
        
        // Reset Streak for demo
        UserDefaults.standard.set(4, forKey: "currentStreak") // Fake 4 day streak
        UserDefaults.standard.set(7, forKey: "longestStreak")
    }
    
    private func clearAllBookmarks() {
        try? modelContext.delete(model: Bookmark.self)
    }
    #endif
}

// MARK: - Expiration Urgency Priority Extension

extension ExpirationUrgency {
    var priority: Int {
        switch self {
        case .critical: return 4
        case .urgent: return 3
        case .warning: return 2
        case .safe: return 1
        }
    }
}

// MARK: - Hero Focus Card (v2.1 Updated)

struct HeroFocusCard: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    let onBurn: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail (100x100)
                ZStack {
                    if let url = bookmark.displayImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                if bookmark.shouldShowFaviconFallback {
                                    // Favicon - center it with background
                                    ZStack {
                                        Color.joltCardBackground
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 48, height: 48)
                                    }
                                } else {
                                    // Cover image - fill the space
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                            case .failure:
                                thumbnailPlaceholder
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.joltCardBackground)
                            @unknown default:
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .clipped()
                .accessibilityHidden(true)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // v2.1: Expiration Badge + Collection
                    HStack(spacing: 8) {
                        // Expiration countdown
                        if !bookmark.countdownText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                Text(bookmark.countdownText)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(bookmark.expirationUrgency.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(bookmark.expirationUrgency.color.opacity(0.15))
                            .cornerRadius(6)
                        }
                        
                        // Collection Badge

                    }
                    
                    // Title
                    Text(bookmark.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Meta
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            if let icon = bookmark.platformIcon {
                                Image(systemName: icon)
                                    .font(.system(size: 10))
                            }
                            Text(bookmark.domain.replacingOccurrences(of: "www.", with: ""))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.joltMutedForeground)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.joltMutedForeground.opacity(0.5))
                        
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(bookmark.readingTimeMinutes) dk")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.joltMutedForeground)
                    }
                    .accessibilityHidden(true)
                }
                
                Spacer(minLength: 0)
                
                // Jolt Button
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.joltYellow)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color.joltCardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(A11y.Focus.openReaderHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityActions {
            Button(A11y.Focus.archiveHint) { onArchive() }
            Button(A11y.Focus.snoozeHint) { onSnooze() }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onArchive()
            } label: {
                Label("common.complete".localized, systemImage: "checkmark")
            }
            .tint(.joltYellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onBurn()
            } label: {
                Label("common.burn".localized, systemImage: "flame.fill")
            }
            .tint(.red)
            
            Button {
                onSnooze()
            } label: {
                Label("common.snooze".localized, systemImage: "clock.arrow.circlepath")
            }
            .tint(.gray)
        }
    }
    
    private var accessibilityLabel: String {
        var label = A11y.Focus.bookmarkCard(
            title: bookmark.title,
            domain: bookmark.domain.replacingOccurrences(of: "www.", with: ""),
            readingTime: bookmark.readingTimeMinutes
        )

        if !bookmark.countdownText.isEmpty {
            label += " \(bookmark.countdownText) kaldı."
        }
        return label
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.joltMuted
            Image(systemName: bookmark.type.icon)
                .font(.system(size: 28))
                .foregroundColor(.joltMutedForeground)
        }
    }
}

// MARK: - Ultra Compact Row (v2.1 Updated)

struct UltraCompactRow: View {
    let bookmark: Bookmark
    var isUpcoming: Bool = false
    let onTap: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    let onBurn: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // v2.1: Expiration color bar instead of collection
                RoundedRectangle(cornerRadius: 2)
                    .fill(isUpcoming ? Color.joltMuted : bookmark.expirationUrgency.color)
                    .frame(width: 4)
                
                // Title
                Text(bookmark.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.joltForeground)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                // Duration or Scheduled Time
                if isUpcoming {
                    // v2.1 DOZ: Planlanmış zaman - "Bugün 21:00" veya "Yarın 08:30" gibi
                    Text(formatScheduledTime(bookmark.scheduledFor))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.joltYellow)
                } else {
                    // Show remaining days with color
                    Text(bookmark.countdownText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(bookmark.expirationUrgency.color)
                    
                    Text("\(bookmark.readingTimeMinutes) dk")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.joltMutedForeground)
                }
                
                // Bolt Icon with urgency color
                if !isUpcoming {
                    UrgencyBoltIcon(urgency: bookmark.expirationUrgency)
                } else {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.joltMutedForeground)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.joltCardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isUpcoming ? A11y.Focus.pullForwardHint : A11y.Focus.openReaderHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityActions {
            Button(A11y.Focus.archiveHint) { onArchive() }
            if !isUpcoming {
                Button(A11y.Focus.snoozeHint) { onSnooze() }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onArchive()
            } label: {
                Label("common.complete".localized, systemImage: "checkmark")
            }
            .tint(.joltYellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onBurn()
            } label: {
                Label("common.burn".localized, systemImage: "flame.fill")
            }
            .tint(.red)
            
            if !isUpcoming {
                Button {
                    onSnooze()
                } label: {
                    Label("common.snooze".localized, systemImage: "clock.arrow.circlepath")
                }
                .tint(.gray)
            }
        }
    }
    
    private var accessibilityLabel: String {
        var label = bookmark.title
        if isUpcoming {
            label += ". \(formatScheduledTime(bookmark.scheduledFor)) için planlandı."
        } else {
            label += ". \(bookmark.readingTimeMinutes) dakika."
            if !bookmark.countdownText.isEmpty {
                label += " \(bookmark.countdownText) kaldı."
            }
        }

        return label
    }
    
    /// Planlanmış zamanı okunabilir formatta döndürür
    /// Örn: "Bugün 21:00", "Yarın 08:30", "Pzt 09:00"
    private func formatScheduledTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "focus.scheduled.today".localized + " " + timeString
        } else if calendar.isDateInTomorrow(date) {
            return "focus.scheduled.tomorrow".localized + " " + timeString
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale.current
            dayFormatter.dateFormat = "EEE" // Kısa gün adı: Pzt, Sal, etc.
            return dayFormatter.string(from: date) + " " + timeString
        }
    }
}

// MARK: - Breathing Empty State

struct BreathingEmptyState: View {
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.joltYellow.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.2 : 0.9))
                    .opacity(reduceMotion ? 0.5 : (isBreathing ? 0.6 : 0.3))
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.joltYellow.opacity(0.5), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.1 : 0.95))
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.joltYellow, Color(hex: "#AADD00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.joltYellow.opacity(0.5), radius: 20)
                    .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.05 : 1.0))
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("focus.allCaughtUp".localized)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.joltForeground)
                
                Text("empty.focus.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(.joltMutedForeground)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("a11y.focus.empty".localized)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Expiration Urgency Color Extension

extension ExpirationUrgency {
    var color: Color {
        switch self {
        case .safe: return .joltYellow
        case .warning: return .yellow
        case .urgent: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Urgency Bolt Icon View

struct UrgencyBoltIcon: View {
    let urgency: ExpirationUrgency
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(urgency.color)
            .opacity(urgency == .critical ? (isAnimating ? 0.4 : 1.0) : 1.0)
            .scaleEffect(urgency == .critical ? (isAnimating ? 0.9 : 1.1) : 1.0)
            .onAppear {
                if urgency == .critical {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    FocusView()
        .modelContainer(for: [Bookmark.self, Routine.self], inMemory: true)
}
