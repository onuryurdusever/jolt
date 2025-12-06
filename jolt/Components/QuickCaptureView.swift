//
//  QuickCaptureView.swift
//  jolt
//
//  Shared component for quick link capture - used by both Share Extension and Main App
//  Created by Onur Yurdusever on 4.12.2025.
//

import SwiftUI
import SwiftData
import LinkPresentation
import Combine

// MARK: - Capture Source

enum CaptureSource {
    case shareExtension
    case clipboard
}

// MARK: - Save Result

enum SaveResult {
    case saved
    case cancelled
    case error(String)
}

// MARK: - Link Metadata

@MainActor
class LinkMetadataLoader: ObservableObject {
    @Published var title: String?
    @Published var imageData: Data?
    @Published var isLoading = true
    @Published var loadFailed = false
    
    private var loadTask: Task<Void, Never>?
    
    func load(url: URL) {
        loadTask?.cancel()
        isLoading = true
        loadFailed = false
        
        loadTask = Task {
            let provider = LPMetadataProvider()
            provider.timeout = 2.0 // 2 second timeout as per spec
            
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                
                if Task.isCancelled { return }
                
                self.title = metadata.title
                
                // Try to get image
                if let imageProvider = metadata.imageProvider {
                    imageProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                        DispatchQueue.main.async {
                            if let uiImage = image as? UIImage {
                                self?.imageData = uiImage.jpegData(compressionQuality: 0.7)
                            }
                        }
                    }
                }
                
                self.isLoading = false
            } catch {
                if Task.isCancelled { return }
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
    
    func cancel() {
        loadTask?.cancel()
    }
}

// MARK: - Quick Capture View

struct QuickCaptureView: View {
    let url: String
    let source: CaptureSource
    let onComplete: (SaveResult) -> Void
    
    // For Share Extension - needs explicit userID
    var userID: String?
    // For Main App - can use modelContext directly
    var modelContext: ModelContext?
    
    @Environment(\.modelContext) private var envModelContext
    @Query(sort: \Routine.hour) private var routines: [Routine]
    @Query(sort: \Collection.createdAt) private var collections: [Collection]
    
    // Metadata
    @StateObject private var metadataLoader = LinkMetadataLoader()
    
    // UI State
    @State private var userNote: String = ""
    @State private var selectedCollection: Collection?
    @State private var showDatePicker = false
    @State private var customDate = Date()
    @State private var showSuccess = false
    @State private var isDuplicate = false
    @State private var isOffline = false
    @FocusState private var isNoteFocused: Bool
    
    // Shared UserDefaults
    private let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
    
    // MARK: - Computed Properties
    
    private var effectiveModelContext: ModelContext {
        modelContext ?? envModelContext
    }
    
    private var effectiveUserID: String {
        userID ?? AuthService.shared.currentUserID ?? "anonymous"
    }
    
    private var domain: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? "unknown"
    }
    
    private var displayTitle: String {
        metadataLoader.title ?? domain
    }
    
    private var nextRoutineTime: Date {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        let activeRoutines = routines.filter { $0.isEnabled }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        
        guard !activeRoutines.isEmpty else {
            return now.addingTimeInterval(3 * 3600)
        }
        
        // Find next routine today
        for routine in activeRoutines {
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
        
        // Find next routine in upcoming days
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let futureWeekday = calendar.component(.weekday, from: futureDate)
            
            for routine in activeRoutines {
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
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
    
    /// Returns the 2nd upcoming routine time (skip one)
    private var secondRoutineTime: Date {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        let activeRoutines = routines.filter { $0.isEnabled }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        
        guard !activeRoutines.isEmpty else {
            // No routines: return 6 hours from now
            return now.addingTimeInterval(6 * 3600)
        }
        
        // Collect all upcoming routine times
        var upcomingTimes: [Date] = []
        
        // Check today's remaining routines
        for routine in activeRoutines {
            let routineMinutes = routine.hour * 60 + routine.minute
            let currentMinutes = currentHour * 60 + currentMinute
            
            if routineMinutes > currentMinutes && routine.days.contains(currentWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = routine.hour
                components.minute = routine.minute
                if let date = calendar.date(from: components) {
                    upcomingTimes.append(date)
                }
            }
        }
        
        // Check upcoming days (up to 7 days)
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let futureWeekday = calendar.component(.weekday, from: futureDate)
            
            for routine in activeRoutines {
                if routine.days.contains(futureWeekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
                    components.hour = routine.hour
                    components.minute = routine.minute
                    if let date = calendar.date(from: components) {
                        upcomingTimes.append(date)
                    }
                }
            }
            
            // Stop if we have at least 2 times
            if upcomingTimes.count >= 2 { break }
        }
        
        // Sort and return 2nd one
        upcomingTimes.sort()
        if upcomingTimes.count >= 2 {
            return upcomingTimes[1]
        } else if let first = upcomingTimes.first {
            // Only 1 routine found, add 1 day to it
            return calendar.date(byAdding: .day, value: 1, to: first) ?? first.addingTimeInterval(24 * 3600)
        }
        
        // Fallback: day after tomorrow 9 AM
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: now)!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayAfterTomorrow) ?? dayAfterTomorrow
    }
    
    private var recentCollections: [Collection] {
        // Get recent collection IDs from UserDefaults
        guard let recentIDs = defaults?.array(forKey: "recentCollectionIDs") as? [String] else {
            return Array(collections.prefix(3))
        }
        
        // Map IDs to collections, maintaining order
        var result: [Collection] = []
        for idString in recentIDs {
            if let uuid = UUID(uuidString: idString),
               let collection = collections.first(where: { $0.id == uuid }) {
                result.append(collection)
            }
        }
        
        // Fill remaining slots with other collections
        for collection in collections where !result.contains(where: { $0.id == collection.id }) {
            if result.count >= 3 { break }
            result.append(collection)
        }
        
        return Array(result.prefix(3))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Link Preview Card
                        linkPreviewCard
                            .padding(.horizontal, 20)
                        
                        // Note Input (Compact)
                        noteInput
                            .padding(.horizontal, 20)
                        
                        // Smart Collection Chips
                        if !recentCollections.isEmpty {
                            collectionChips
                        }
                        
                        // Action Buttons (2x2 Grid)
                        actionButtonGrid
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color.joltBackground)
            
            // Success Overlay
            if showSuccess {
                successOverlay
            }
        }
        .onAppear {
            loadDraft()
            checkForDuplicate()
            checkNetworkStatus()
            if let parsedURL = URL(string: url) {
                metadataLoader.load(url: parsedURL)
            }
        }
        .onChange(of: userNote) { _, newValue in
            saveDraft(newValue)
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("quickCapture.joltIt".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.joltForeground)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.joltYellow)
            
            Spacer()
            
            Button {
                clearDraft()
                onComplete(.cancelled)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.joltMutedForeground)
            }
        }
    }
    
    // MARK: - Link Preview Card
    
    private var linkPreviewCard: some View {
        HStack(spacing: 12) {
            // Thumbnail (80x80)
            ZStack {
                if metadataLoader.isLoading {
                    // Skeleton with shimmer
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.joltMuted)
                        .overlay(
                            ShimmerView()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        )
                } else if let imageData = metadataLoader.imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback: Domain initial or icon
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.joltMuted)
                        .overlay(
                            Text(domain.prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.joltMutedForeground)
                        )
                }
            }
            .frame(width: 80, height: 80)
            
            // Title & Domain
            VStack(alignment: .leading, spacing: 6) {
                if metadataLoader.isLoading {
                    // Skeleton for title
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.joltMuted)
                        .frame(height: 18)
                        .overlay(ShimmerView().clipShape(RoundedRectangle(cornerRadius: 4)))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.joltMuted)
                        .frame(width: 120, height: 14)
                        .overlay(ShimmerView().clipShape(RoundedRectangle(cornerRadius: 4)))
                } else {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text(domain)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.joltMutedForeground)
                }
                
                // Duplicate badge
                if isDuplicate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("quickCapture.alreadySaved".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.joltYellow)
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.joltCardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Note Input
    
    private var noteInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.system(size: 12))
                    .foregroundColor(.joltMutedForeground)
                
                TextField("Add context...", text: $userNote, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(.joltForeground)
                    .lineLimit(1...3)
                    .focused($isNoteFocused)
            }
            .padding(12)
            .background(Color.joltCardBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Collection Chips
    
    private var collectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // No Collection chip
                CollectionChip(
                    name: "No Collection",
                    icon: "tray.fill",
                    color: "#8E8E93",
                    isSelected: selectedCollection == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCollection = nil
                    }
                }
                
                // Recent collections
                ForEach(recentCollections) { collection in
                    CollectionChip(
                        name: collection.name,
                        icon: collection.icon,
                        color: collection.color,
                        isSelected: selectedCollection?.id == collection.id
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCollection = collection
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Action Button Grid
    
    private var actionButtonGrid: some View {
        VStack(spacing: 10) {
            // Row 1: Next Routine (Primary) + Skip One
            HStack(spacing: 10) {
                // Next Routine / Bump to Top
                ActionButton(
                    title: isDuplicate ? "Bump to Top" : formatRoutineLabel(nextRoutineTime),
                    icon: isDuplicate ? "arrow.up.circle.fill" : "bolt.fill",
                    style: .primary
                ) {
                    saveAndComplete(scheduledFor: nextRoutineTime)
                }
                
                // Skip One (2nd routine)
                ActionButton(
                    title: formatRoutineLabel(secondRoutineTime),
                    icon: "forward.fill",
                    style: .secondary
                ) {
                    saveAndComplete(scheduledFor: secondRoutineTime)
                }
            }
            
            // Row 2: No Reminder + Pick Time
            HStack(spacing: 10) {
                // No Reminder (Library only, no scheduledFor)
                ActionButton(
                    title: "No Reminder",
                    icon: "tray.fill",
                    style: .secondary
                ) {
                    saveAndComplete(scheduledFor: nil)
                }
                
                // Pick Time
                ActionButton(
                    title: "Pick Time",
                    icon: "calendar",
                    style: .secondary
                ) {
                    showDatePicker = true
                }
            }
        }
    }
    
    // MARK: - Date Picker Sheet
    
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "When to read?",
                    selection: $customDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(.joltYellow)
                .padding()
                
                Spacer()
            }
            .background(Color.joltBackground)
            .navigationTitle("Pick Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showDatePicker = false
                    }
                    .foregroundColor(.joltMutedForeground)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDatePicker = false
                        saveAndComplete(scheduledFor: customDate)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.joltYellow)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.joltYellow)
                    .scaleEffect(showSuccess ? 1.0 : 0.5)
                    .opacity(showSuccess ? 1.0 : 0)
                
                Text(isOffline ? "Saved (Offline)" : "Saved")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.joltForeground)
                    .opacity(showSuccess ? 1.0 : 0)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccess)
    }
    
    // MARK: - Actions
    
    private func saveAndComplete(scheduledFor: Date?) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Save bookmark
        performSave(scheduledFor: scheduledFor)
        
        // Update recent collections
        if let collection = selectedCollection {
            updateRecentCollections(with: collection.id)
        }
        
        // Show success animation
        withAnimation {
            showSuccess = true
        }
        
        // Delay then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            clearDraft()
            onComplete(.saved)
        }
    }
    
    private func performSave(scheduledFor: Date?) {
        let context = effectiveModelContext
        let userId = effectiveUserID
        
        // Check for existing bookmark
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.originalURL == url && bookmark.userID == userId
            }
        )
        
        do {
            if let existing = try context.fetch(descriptor).first {
                // Update existing
                existing.createdAt = Date()
                existing.scheduledFor = scheduledFor ?? Date().addingTimeInterval(365 * 24 * 3600) // Far future for "Later"
                existing.userNote = userNote.isEmpty ? nil : userNote
                existing.collection = selectedCollection
                if existing.status == .archived {
                    existing.status = .pending
                }
            } else {
                // Create new
                let bookmark = Bookmark(
                    userID: userId,
                    originalURL: url,
                    status: .pending,
                    scheduledFor: scheduledFor ?? Date().addingTimeInterval(365 * 24 * 3600),
                    title: metadataLoader.title ?? domain,
                    type: detectBookmarkType(),
                    domain: URL(string: url)?.host ?? "unknown",
                    userNote: userNote.isEmpty ? nil : userNote,
                    collection: selectedCollection
                )
                context.insert(bookmark)
            }
            
            try context.save()
            
            // Trigger sync for main app
            if source == .clipboard {
                Task {
                    await SyncService.shared.syncPendingBookmarks(context: context)
                }
            }
        } catch {
            print("❌ Failed to save bookmark: \(error)")
        }
    }
    
    private func detectBookmarkType() -> BookmarkType {
        let host = (URL(string: url)?.host ?? "").lowercased()
        let socialDomains = ["twitter.com", "x.com", "instagram.com", "tiktok.com", "youtube.com", "facebook.com", "threads.net", "linkedin.com"]
        return socialDomains.contains(where: { host.contains($0) }) ? .social : .article
    }
    
    // MARK: - Helpers
    
    private func formatRoutineLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h a" // "9 AM" format
        let timeString = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            // Today: "This Morning 9 AM" or "Tonight 9 PM"
            if hour < 12 {
                return "This Morning"
            } else if hour < 17 {
                return "This Afternoon"
            } else {
                return "Tonight \(timeString)"
            }
        } else if calendar.isDateInTomorrow(date) {
            // Tomorrow: "Tomorrow 9 AM"
            return "Tomorrow \(timeString)"
        } else {
            // Day name: "Saturday 10 AM"
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE" // Full day name
            return "\(dayFormatter.string(from: date)) \(timeString)"
        }
    }
    
    private func checkForDuplicate() {
        let context = effectiveModelContext
        let userId = effectiveUserID
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.originalURL == url && bookmark.userID == userId
            }
        )
        
        if let _ = try? context.fetch(descriptor).first {
            isDuplicate = true
        }
    }
    
    private func checkNetworkStatus() {
        // Simple check - could use NetworkMonitor for more robust solution
        isOffline = !NetworkMonitor.shared.isOnline
    }
    
    private func updateRecentCollections(with collectionID: UUID) {
        var recentIDs = defaults?.array(forKey: "recentCollectionIDs") as? [String] ?? []
        
        // Remove if exists, add to front
        recentIDs.removeAll { $0 == collectionID.uuidString }
        recentIDs.insert(collectionID.uuidString, at: 0)
        
        // Keep only last 10
        recentIDs = Array(recentIDs.prefix(10))
        
        defaults?.set(recentIDs, forKey: "recentCollectionIDs")
    }
    
    // Draft persistence
    private func loadDraft() {
        guard let savedUrl = defaults?.string(forKey: "draft_url"), savedUrl == url else { return }
        userNote = defaults?.string(forKey: "draft_note") ?? ""
    }
    
    private func saveDraft(_ note: String) {
        defaults?.set(url, forKey: "draft_url")
        defaults?.set(note, forKey: "draft_note")
    }
    
    private func clearDraft() {
        defaults?.removeObject(forKey: "draft_url")
        defaults?.removeObject(forKey: "draft_note")
    }
}

// MARK: - Collection Chip

struct CollectionChip: View {
    let name: String
    let icon: String
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 8, height: 8)
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .joltBackground : .joltForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.joltYellow : Color.joltCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.joltBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    enum Style {
        case primary
        case secondary
    }
    
    let title: String
    let icon: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(style == .primary ? .joltBackground : .joltForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(style == .primary ? Color.joltYellow : Color.joltCardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.1),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: phase)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 200
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QuickCaptureView(
        url: "https://medium.com/some-article",
        source: .clipboard,
        onComplete: { _ in }
    )
    .modelContainer(for: [Bookmark.self, Collection.self, Routine.self], inMemory: true)
}
