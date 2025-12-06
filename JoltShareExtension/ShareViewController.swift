//
//  ShareViewController.swift
//  JoltShareExtension
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications
import LinkPresentation
import Combine

class ShareViewController: UIViewController {
    private var sharedURL: String?
    private var modelContainer: ModelContainer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SwiftData Container
        setupModelContainer()
        
        // Show loading state
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Set preferred content size for compact sheet (~40% of screen)
        self.preferredContentSize = CGSize(width: 0, height: 420)
        
        // First try clipboard (for quick add action)
        if let clipboardURL = checkClipboard() {
            print("✅ Found URL in clipboard: \(clipboardURL)")
            self.sharedURL = clipboardURL
            presentQuickCapture(with: clipboardURL)
        } else {
            // Fall back to share sheet data
            extractURL()
        }
    }
    
    private func setupModelContainer() {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jolt.shared") else {
            print("❌ Failed to get App Group container")
            return
        }
        
        let schema = Schema([Bookmark.self, Collection.self, Routine.self])
        let modelConfiguration = ModelConfiguration(
            url: appGroupURL.appendingPathComponent("jolt.sqlite"),
            allowsSave: true
        )
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ShareExtension ModelContainer created")
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
        }
    }
    
    private func checkClipboard() -> String? {
        guard let pasteboardString = UIPasteboard.general.string else { return nil }
        if let url = URL(string: pasteboardString), 
           url.scheme == "http" || url.scheme == "https" {
            return pasteboardString
        }
        return nil
    }
    
    private func presentQuickCapture(with url: String) {
        guard let container = modelContainer else {
            print("❌ No ModelContainer available")
            extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -4))
            return
        }
        
        let userID = loadUserID() ?? "anonymous"
        
        let rootView = ExtensionQuickCaptureView(
            url: url,
            userID: userID,
            onComplete: { [weak self] result in
                switch result {
                case .saved:
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                case .cancelled:
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -1))
                case .error(let message):
                    print("❌ Save error: \(message)")
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -2))
                }
            }
        )
        .modelContainer(container)
        
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func extractURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else { return }
        
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                    if let shareURL = url as? URL {
                        DispatchQueue.main.async {
                            self?.sharedURL = shareURL.absoluteString
                            self?.presentQuickCapture(with: shareURL.absoluteString)
                        }
                    } else if let urlString = url as? String {
                        DispatchQueue.main.async {
                            self?.sharedURL = urlString
                            self?.presentQuickCapture(with: urlString)
                        }
                    }
                }
                return
            }
            
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (text, error) in
                    if let urlString = text as? String {
                        DispatchQueue.main.async {
                            self?.sharedURL = urlString
                            self?.presentQuickCapture(with: urlString)
                        }
                    }
                }
                return
            }
        }
    }
    
    private func loadUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jolt.userId",
            kSecAttrAccessGroup as String: "group.com.jolt.shared",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Save Result

enum ExtensionSaveResult {
    case saved
    case cancelled
    case error(String)
}

// MARK: - Link Metadata Loader

@MainActor
class ExtensionMetadataLoader: ObservableObject {
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
            provider.timeout = 2.0
            
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                
                if Task.isCancelled { return }
                
                self.title = metadata.title
                
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
}

// MARK: - Extension Quick Capture View

struct ExtensionQuickCaptureView: View {
    let url: String
    let userID: String
    let onComplete: (ExtensionSaveResult) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.hour) private var routines: [Routine]
    @Query(sort: \Collection.createdAt) private var collections: [Collection]
    
    @StateObject private var metadataLoader = ExtensionMetadataLoader()
    
    @State private var userNote: String = ""
    @State private var selectedCollection: Collection?
    @State private var showDatePicker = false
    @State private var customDate = Date()
    @State private var showSuccess = false
    @State private var isDuplicate = false
    
    private let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
    
    // MARK: - Computed Properties
    
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
            return now.addingTimeInterval(6 * 3600)
        }
        
        var upcomingTimes: [Date] = []
        
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
            
            if upcomingTimes.count >= 2 { break }
        }
        
        upcomingTimes.sort()
        if upcomingTimes.count >= 2 {
            return upcomingTimes[1]
        } else if let first = upcomingTimes.first {
            return calendar.date(byAdding: .day, value: 1, to: first) ?? first.addingTimeInterval(24 * 3600)
        }
        
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: now)!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayAfterTomorrow) ?? dayAfterTomorrow
    }
    
    private var recentCollections: [Collection] {
        guard let recentIDs = defaults?.array(forKey: "recentCollectionIDs") as? [String] else {
            return Array(collections.prefix(3))
        }
        
        var result: [Collection] = []
        for idString in recentIDs {
            if let uuid = UUID(uuidString: idString),
               let collection = collections.first(where: { $0.id == uuid }) {
                result.append(collection)
            }
        }
        
        for collection in collections where !result.contains(where: { $0.id == collection.id }) {
            if result.count >= 3 { break }
            result.append(collection)
        }
        
        return Array(result.prefix(3))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 16) {
                        linkPreviewCard
                            .padding(.horizontal, 20)
                        
                        noteInput
                            .padding(.horizontal, 20)
                        
                        if !recentCollections.isEmpty {
                            collectionChips
                        }
                        
                        actionButtonGrid
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color(hex: "#000000"))
            
            if showSuccess {
                successOverlay
            }
        }
        .onAppear {
            loadDraft()
            checkForDuplicate()
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
            Text("shareExtension.joltIt".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#CCFF00"))
            
            Spacer()
            
            Button {
                clearDraft()
                onComplete(.cancelled)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#8E8E93"))
            }
        }
    }
    
    // MARK: - Link Preview Card
    
    private var linkPreviewCard: some View {
        HStack(spacing: 12) {
            ZStack {
                if metadataLoader.isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#2C2C2E"))
                        .overlay(ExtensionShimmerView().clipShape(RoundedRectangle(cornerRadius: 12)))
                } else if let imageData = metadataLoader.imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#2C2C2E"))
                        .overlay(
                            Text(domain.prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#8E8E93"))
                        )
                }
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 6) {
                if metadataLoader.isLoading {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#2C2C2E"))
                        .frame(height: 18)
                        .overlay(ExtensionShimmerView().clipShape(RoundedRectangle(cornerRadius: 4)))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#2C2C2E"))
                        .frame(width: 120, height: 14)
                } else {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text(domain)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "#8E8E93"))
                }
                
                if isDuplicate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("shareExtension.alreadySaved".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#CCFF00"))
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(16)
    }
    
    // MARK: - Note Input
    
    private var noteInput: some View {
        HStack {
            Image(systemName: "text.quote")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#8E8E93"))
            
            TextField("Add context...", text: $userNote, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1...3)
        }
        .padding(12)
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(12)
    }
    
    // MARK: - Collection Chips
    
    private var collectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ExtensionCollectionChip(
                    name: "No Collection",
                    color: "#8E8E93",
                    isSelected: selectedCollection == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCollection = nil
                    }
                }
                
                ForEach(recentCollections) { collection in
                    ExtensionCollectionChip(
                        name: collection.name,
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
            HStack(spacing: 10) {
                ExtensionActionButton(
                    title: isDuplicate ? "Bump to Top" : formatRoutineLabel(nextRoutineTime),
                    icon: isDuplicate ? "arrow.up.circle.fill" : "bolt.fill",
                    isPrimary: true
                ) {
                    saveAndComplete(scheduledFor: nextRoutineTime)
                }
                
                ExtensionActionButton(
                    title: formatRoutineLabel(secondRoutineTime),
                    icon: "forward.fill",
                    isPrimary: false
                ) {
                    saveAndComplete(scheduledFor: secondRoutineTime)
                }
            }
            
            HStack(spacing: 10) {
                ExtensionActionButton(
                    title: "No Reminder",
                    icon: "tray.fill",
                    isPrimary: false
                ) {
                    saveAndComplete(scheduledFor: nil)
                }
                
                ExtensionActionButton(
                    title: "Pick Time",
                    icon: "calendar",
                    isPrimary: false
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
                .tint(Color(hex: "#CCFF00"))
                .padding()
                
                Spacer()
            }
            .background(Color(hex: "#000000"))
            .navigationTitle("Pick Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showDatePicker = false
                    }
                    .foregroundColor(Color(hex: "#8E8E93"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDatePicker = false
                        saveAndComplete(scheduledFor: customDate)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#CCFF00"))
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
                    .foregroundColor(Color(hex: "#CCFF00"))
                    .scaleEffect(showSuccess ? 1.0 : 0.5)
                    .opacity(showSuccess ? 1.0 : 0)
                
                Text("shareExtension.saved".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(showSuccess ? 1.0 : 0)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccess)
    }
    
    // MARK: - Actions
    
    private func saveAndComplete(scheduledFor: Date?) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        performSave(scheduledFor: scheduledFor)
        
        if let collection = selectedCollection {
            updateRecentCollections(with: collection.id)
        }
        
        withAnimation {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            clearDraft()
            onComplete(.saved)
        }
    }
    
    private func performSave(scheduledFor: Date?) {
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.originalURL == url && bookmark.userID == userID
            }
        )
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.createdAt = Date()
                existing.scheduledFor = scheduledFor ?? Date().addingTimeInterval(365 * 24 * 3600)
                existing.userNote = userNote.isEmpty ? nil : userNote
                existing.collection = selectedCollection
                if existing.status == .archived {
                    existing.status = .pending
                }
            } else {
                let bookmark = Bookmark(
                    userID: userID,
                    originalURL: url,
                    status: .pending,
                    scheduledFor: scheduledFor ?? Date().addingTimeInterval(365 * 24 * 3600),
                    title: metadataLoader.title ?? domain,
                    type: detectBookmarkType(),
                    domain: URL(string: url)?.host ?? "unknown",
                    userNote: userNote.isEmpty ? nil : userNote,
                    collection: selectedCollection
                )
                modelContext.insert(bookmark)
            }
            
            try modelContext.save()
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
        timeFormatter.dateFormat = "h a"
        let timeString = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            if hour < 12 {
                return "This Morning"
            } else if hour < 17 {
                return "This Afternoon"
            } else {
                return "Tonight \(timeString)"
            }
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return "\(dayFormatter.string(from: date)) \(timeString)"
        }
    }
    
    private func checkForDuplicate() {
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.originalURL == url && bookmark.userID == userID
            }
        )
        
        if let _ = try? modelContext.fetch(descriptor).first {
            isDuplicate = true
        }
    }
    
    private func updateRecentCollections(with collectionID: UUID) {
        var recentIDs = defaults?.array(forKey: "recentCollectionIDs") as? [String] ?? []
        recentIDs.removeAll { $0 == collectionID.uuidString }
        recentIDs.insert(collectionID.uuidString, at: 0)
        recentIDs = Array(recentIDs.prefix(10))
        defaults?.set(recentIDs, forKey: "recentCollectionIDs")
    }
    
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

// MARK: - Extension Collection Chip

struct ExtensionCollectionChip: View {
    let name: String
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
            .foregroundColor(isSelected ? Color(hex: "#000000") : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "#CCFF00") : Color(hex: "#1C1C1E"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(hex: "#383838"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extension Action Button

struct ExtensionActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
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
            .foregroundColor(isPrimary ? Color(hex: "#000000") : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isPrimary ? Color(hex: "#CCFF00") : Color(hex: "#1C1C1E"))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extension Shimmer View

struct ExtensionShimmerView: View {
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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
