//
//  FocusView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData
import Combine

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var syncService = SyncService.shared
    @Query private var allBookmarks: [Bookmark]
    @Query private var allRoutines: [Routine]
    @Query private var allCollections: [Collection]
    
    // Timer for refreshing "now" - triggers view update every 30 seconds
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var currentTime = Date()
    
    // UI State
    @State private var selectedBookmark: Bookmark?
    @State private var showFilterSheet = false
    @State private var showQuickAdd = false
    @State private var clipboardURL: String = ""
    @State private var isListExpanded = false
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
    
    // MARK: - Computed Properties
    
    private var readyBookmarks: [Bookmark] {
        // Use currentTime state to ensure view updates when time changes
        let now = currentTime
        return allBookmarks
            .filter { ($0.status == .ready || $0.status == .pending) && $0.scheduledFor <= now }
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    private var filteredBookmarks: [Bookmark] {
        guard let maxMinutes = selectedFilter.maxMinutes else { return readyBookmarks }
        return readyBookmarks.filter { $0.readingTimeMinutes <= maxMinutes }
    }
    
    private var upcomingBookmarks: [Bookmark] {
        // Use currentTime state to ensure view updates when time changes
        let now = currentTime
        return allBookmarks
            .filter { ($0.status == .ready || $0.status == .pending) && $0.scheduledFor > now }
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    private var totalReadingTime: Int {
        filteredBookmarks.reduce(0) { $0 + $1.readingTimeMinutes }
    }
    
    private var visibleBookmarks: [Bookmark] {
        if isListExpanded || filteredBookmarks.count <= 4 {
            return filteredBookmarks
        }
        return Array(filteredBookmarks.prefix(3))
    }
    
    private var hiddenCount: Int {
        max(0, filteredBookmarks.count - 3)
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
                        // No ready bookmarks, but has upcoming
                        ScrollView {
                            VStack(spacing: 16) {
                                breathingEmptyState
                                    .frame(height: 300)
                                
                                // Later Section
                                laterSection
                                    .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await syncService.syncPendingBookmarks(context: modelContext)
                        }
                    } else {
                        // Content
                        ScrollView {
                            VStack(spacing: 12) {
                                // Hero Card (First Item)
                                if let heroBookmark = filteredBookmarks.first {
                                    HeroFocusCard(
                                        bookmark: heroBookmark,
                                        onTap: { selectedBookmark = heroBookmark },
                                        onArchive: { archiveBookmark(heroBookmark) },
                                        onSnooze: { snoozeToNextRoutine(heroBookmark) }
                                    )
                                    .padding(.horizontal, 20)
                                }
                                
                                // Ultra-Compact Rows (Rest)
                                if filteredBookmarks.count > 1 {
                                    VStack(spacing: 8) {
                                        ForEach(Array(visibleBookmarks.dropFirst())) { bookmark in
                                            UltraCompactRow(
                                                bookmark: bookmark,
                                                onTap: { selectedBookmark = bookmark },
                                                onArchive: { archiveBookmark(bookmark) },
                                                onSnooze: { snoozeToNextRoutine(bookmark) }
                                            )
                                        }
                                        
                                        // "+ X more" button
                                        if !isListExpanded && hiddenCount > 0 {
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    isListExpanded = true
                                                }
                                            } label: {
                                                Text("focus.hero.more".localized(with: hiddenCount))
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.joltMutedForeground)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                
                                // Later Section (Collapsed)
                                if !upcomingBookmarks.isEmpty {
                                    laterSection
                                        .padding(.horizontal, 20)
                                        .padding(.top, 16)
                                }
                            }
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await syncService.syncPendingBookmarks(context: modelContext)
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
                Button("snooze.nextRoutine".localized) { snoozeToNextRoutine(bookmark) }
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
            .clipboardToast(isPresented: $showToast, url: toastURL, type: toastType) {
                handleToastAction()
            }
            .onAppear {
                // Refresh current time on appear to ensure proper filtering
                currentTime = Date()
            }
            .onReceive(timer) { _ in
                // Update current time every 30 seconds for scheduled items
                currentTime = Date()
            }
        }
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
                
                // Clipboard Add
                Button {
                    checkClipboardAndOpen()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.joltYellow)
                }
                .accessibilityLabel("a11y.focus.addFromClipboard".localized)
                .accessibilityHint("a11y.focus.addFromClipboardHint".localized)
            }
        }
    }
    
    // MARK: - Later Section (Collapsed)
    
    private var laterSection: some View {
        VStack(spacing: 8) {
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
            
            if isLaterExpanded {
                VStack(spacing: 8) {
                    ForEach(upcomingBookmarks) { bookmark in
                        UltraCompactRow(
                            bookmark: bookmark,
                            isUpcoming: true,
                            onTap: { pullForward(bookmark) },
                            onArchive: { archiveBookmark(bookmark) },
                            onSnooze: { }
                        )
                    }
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
    
    // MARK: - Actions
    
    private func archiveBookmark(_ bookmark: Bookmark) {
        // Heavy haptic - "Tak!" victory feel
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.status = .archived
            bookmark.readAt = Date()
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
    
    private func snoozeToNextRoutine(_ bookmark: Bookmark) {
        // Light haptic - "Tık" neutral push aside
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        let nextRoutineTime = calculateNextRoutineTime()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.scheduledFor = nextRoutineTime
        }
        try? modelContext.save()
    }
    
    private func snoozeBookmark(_ bookmark: Bookmark, hours: Int) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bookmark.scheduledFor = Date().addingTimeInterval(TimeInterval(hours * 3600))
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                bookmark.scheduledFor = tomorrowMorning
            }
            try? modelContext.save()
        }
    }
    
    private func calculateNextRoutineTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        // Get enabled routines sorted by time
        let enabledRoutines = allRoutines
            .filter { $0.isEnabled }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        
        // If no routines, default to +3 hours
        guard !enabledRoutines.isEmpty else {
            return now.addingTimeInterval(3 * 3600)
        }
        
        // Find next routine today
        for routine in enabledRoutines {
            let routineMinutes = routine.hour * 60 + routine.minute
            let currentMinutes = currentHour * 60 + currentMinute
            
            if routineMinutes > currentMinutes && routine.days.contains(currentWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = routine.hour
                components.minute = routine.minute
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        
        // No routine today, find next available day
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let futureWeekday = calendar.component(.weekday, from: futureDate)
            
            for routine in enabledRoutines {
                if routine.days.contains(futureWeekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
                    components.hour = routine.hour
                    components.minute = routine.minute
                    if let date = calendar.date(from: components) {
                        return date
                    }
                }
            }
        }
        
        // Fallback: tomorrow 9 AM
        return now.addingTimeInterval(24 * 3600)
    }
    
    private func pullForward(_ bookmark: Bookmark) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Only update this specific bookmark
        bookmark.scheduledFor = Date()
        try? modelContext.save()
        
        // Trigger view refresh with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentTime = Date()
        }
    }
    
    private func handleJoltCompletion(for bookmark: Bookmark) {
        selectedBookmark = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            archiveBookmark(bookmark)
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
                    bookmark.status = .ready
                    bookmark.readAt = nil
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
    
    #if DEBUG
    private func generateTestData() {
        let titles = [
            "How to Build a Second Brain with AI",
            "The Future of Swift Concurrency",
            "Why Rust is Taking Over Systems Programming",
            "Design Systems at Scale",
            "Understanding React Server Components",
            "The Art of Minimal UI Design"
        ]
        
        let domains = ["medium.com", "swift.org", "dev.to", "figma.com", "react.dev", "uxdesign.cc"]
        
        // Schedule times: first 2 now, rest in future (Later section)
        let now = Date()
        let scheduleTimes = [
            now,                                           // Now - ready
            now.addingTimeInterval(-60),                   // 1 min ago - ready
            now.addingTimeInterval(2 * 3600),              // 2 hours later
            now.addingTimeInterval(4 * 3600),              // 4 hours later
            now.addingTimeInterval(24 * 3600),             // Tomorrow
            now.addingTimeInterval(48 * 3600)              // Day after tomorrow
        ]
        
        for i in 0..<6 {
            let bookmark = Bookmark(
                userID: "test",
                originalURL: "https://\(domains[i])/article-\(i)",
                status: .ready,
                scheduledFor: scheduleTimes[i],
                title: titles[i],
                readingTimeMinutes: [3, 5, 7, 4, 8, 2][i],
                type: .article,
                domain: domains[i]
            )
            modelContext.insert(bookmark)
        }
        try? modelContext.save()
        print("📝 Test data generated with scheduled times:")
        for i in 0..<6 {
            print("   \(titles[i]): \(scheduleTimes[i])")
        }
    }
    
    private func clearAllBookmarks() {
        try? modelContext.delete(model: Bookmark.self)
    }
    #endif
}

// MARK: - Hero Focus Card

struct HeroFocusCard: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail (100x100)
                ZStack {
                    if let urlStr = bookmark.coverImage, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            thumbnailPlaceholder
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .clipped()
                .accessibilityHidden(true) // Decorative
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Collection Badge (if exists)
                    if let collection = bookmark.collection {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: collection.color))
                                .frame(width: 6, height: 6)
                            Text(collection.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.joltMutedForeground)
                        }
                        .accessibilityHidden(true) // Included in main label
                    }
                    
                    // Title
                    Text(bookmark.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Meta
                    HStack(spacing: 8) {
                        // Domain
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
                        
                        // Duration
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("time.minutes".localized(with: bookmark.readingTimeMinutes))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.joltMutedForeground)
                    }
                    .accessibilityHidden(true) // Included in main label
                }
                
                Spacer(minLength: 0)
                
                // Jolt Button
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.joltYellow)
                    .clipShape(Circle())
                    .accessibilityHidden(true) // Part of main button
            }
            .padding(16)
            .background(Color.joltCardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        // MARK: Accessibility
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
                Label("common.archive".localized, systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onSnooze()
            } label: {
                Label("common.snooze".localized, systemImage: "clock.arrow.circlepath")
            }
            .tint(.joltYellow)
        }
    }
    
    private var accessibilityLabel: String {
        var label = A11y.Focus.bookmarkCard(
            title: bookmark.title,
            domain: bookmark.domain.replacingOccurrences(of: "www.", with: ""),
            readingTime: bookmark.readingTimeMinutes
        )
        if let collection = bookmark.collection {
            label += " \(collection.name) koleksiyonunda."
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

// MARK: - Ultra Compact Row

struct UltraCompactRow: View {
    let bookmark: Bookmark
    var isUpcoming: Bool = false
    let onTap: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Collection Color Bar
                if let collection = bookmark.collection {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: collection.color))
                        .frame(width: 4)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.joltMuted)
                        .frame(width: 4)
                }
                
                // Title
                Text(bookmark.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.joltForeground)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                // Duration or Scheduled Time
                if isUpcoming {
                    Text(bookmark.scheduledFor.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                        .foregroundColor(.joltYellow)
                } else {
                    Text("widget.focus.minutesRead".localized(with: bookmark.readingTimeMinutes))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.joltMutedForeground)
                }
                
                // Action Indicator
                if !isUpcoming {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.joltYellow)
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
        // MARK: Accessibility
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
                Label("common.archive".localized, systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: !isUpcoming) {
            if !isUpcoming {
                Button {
                    onSnooze()
                } label: {
                    Label("common.snooze".localized, systemImage: "clock.arrow.circlepath")
                }
                .tint(.joltYellow)
            }
        }
    }
    
    private var accessibilityLabel: String {
        var label = bookmark.title
        if isUpcoming {
            label += ". \(bookmark.scheduledFor.formatted(.relative(presentation: .named))) için planlandı."
        } else {
            label += ". \(bookmark.readingTimeMinutes) dakika."
        }
        if let collection = bookmark.collection {
            label += " \(collection.name) koleksiyonunda."
        }
        return label
    }
}

// MARK: - Breathing Empty State

struct BreathingEmptyState: View {
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Breathing Bolt
            ZStack {
                // Outer glow
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
                
                // Inner glow
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
                
                // Bolt icon
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
            .accessibilityHidden(true) // Decorative
            
            // Text
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

// MARK: - Preview

#Preview {
    FocusView()
        .modelContainer(for: [Bookmark.self, Collection.self, Routine.self], inMemory: true)
}
