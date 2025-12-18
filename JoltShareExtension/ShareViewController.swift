//
//  ShareViewController.swift
//  JoltShareExtension
//
//  v2.1 - Old elegant design with Expiration Engine data model
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
        
        let schema = Schema([Bookmark.self, Routine.self])
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
                    imageProvider.loadObject(ofClass: UIImage.self) { [weak self] item, error in
                        let data = (item as? UIImage)?.jpegData(compressionQuality: 0.7)
                        DispatchQueue.main.async {
                            self?.imageData = data
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
    
    @StateObject private var metadataLoader = ExtensionMetadataLoader()
    
    @State private var userNote: String = ""
    @State private var selectedCollection: JoltCollection?
    @Query(sort: \JoltCollection.orderIndex) private var collections: [JoltCollection]

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
    
    private var isPro: Bool {
        defaults?.bool(forKey: "is_pro") ?? false
    }
    

    
    // DOZ v2.1: Kullanıcının aktif sabah/akşam rutinleri
    private var morningRoutine: Routine? {
        routines.first { $0.icon == "sun.max.fill" && $0.isEnabled }
    }
    
    private var eveningRoutine: Routine? {
        routines.first { $0.icon == "moon.fill" && $0.isEnabled }
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
                    VStack(spacing: 20) {
                        linkPreviewCard
                            .padding(.horizontal, 20)
                        
                        // v2.1 DOZ Sistemi: Basit 3 seçenek
                        doseSelectionButtons
                            .padding(.horizontal, 20)
                        
                        collectionSelector
                        
                        noteInput
                            .padding(.horizontal, 20)
                        

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
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("shareExtension.joltIt".shareLocalized)
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
                        Text("shareExtension.alreadySaved".shareLocalized)
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
    
    // MARK: - v2.1 DOZ Seçim Butonları
    
    private var doseSelectionButtons: some View {
        VStack(spacing: 12) {
            // Ana satır: Sabah ve Akşam Dozları
            HStack(spacing: 12) {
                // Sabah Dozuna
                DoseButton(
                    title: morningDoseLabel,
                    subtitle: morningRoutine?.timeString ?? "08:30",
                    icon: "sun.max.fill",
                    iconColor: Color.orange
                ) {
                    saveAndComplete(scheduledFor: calculateMorningDoseDate())
                }
                
                // Akşam Dozuna
                DoseButton(
                    title: eveningDoseLabel,
                    subtitle: eveningRoutine?.timeString ?? "21:00",
                    icon: "moon.fill",
                    iconColor: Color.purple
                ) {
                    saveAndComplete(scheduledFor: calculateEveningDoseDate())
                }
            }
            
            // Şimdi Oku - tam genişlik
            Button {
                saveAndComplete(scheduledFor: Date())
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(isDuplicate ? "shareExtension.bumpToTop".shareLocalized : "shareExtension.readNow".shareLocalized)
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#CCFF00"))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Dose Hesaplamaları
    
    private var morningDoseLabel: String {
        let calendar = Calendar.current
        let now = Date()
        
        guard let morning = morningRoutine else {
            return "shareExtension.toMorning".shareLocalized
        }
        
        let morningTime = calendar.date(bySettingHour: morning.hour, minute: morning.minute, second: 0, of: now) ?? now
        
        if morningTime > now {
            return "shareExtension.toMorning".shareLocalized // "Sabaha"
        } else {
            return "shareExtension.tomorrowMorning".shareLocalized // "Yarın Sabaha"
        }
    }
    
    private var eveningDoseLabel: String {
        let calendar = Calendar.current
        let now = Date()
        
        guard let evening = eveningRoutine else {
            return "shareExtension.toEvening".shareLocalized
        }
        
        let eveningTime = calendar.date(bySettingHour: evening.hour, minute: evening.minute, second: 0, of: now) ?? now
        
        if eveningTime > now {
            return "shareExtension.toEvening".shareLocalized // "Akşama"
        } else {
            return "shareExtension.tomorrowEvening".shareLocalized // "Yarın Akşama"
        }
    }
    
    private func calculateMorningDoseDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        let hour = morningRoutine?.hour ?? 8
        let minute = morningRoutine?.minute ?? 30
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        
        guard let todayMorning = calendar.date(from: components) else { return now }
        
        if todayMorning > now {
            return todayMorning
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayMorning) ?? todayMorning
        }
    }
    
    private func calculateEveningDoseDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        let hour = eveningRoutine?.hour ?? 21
        let minute = eveningRoutine?.minute ?? 0
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        
        guard let todayEvening = calendar.date(from: components) else { return now }
        
        if todayEvening > now {
            return todayEvening
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayEvening) ?? todayEvening
        }
    }
    
    // MARK: - Note Input
    
    private var noteInput: some View {
        HStack {
            Image(systemName: "text.quote")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#8E8E93"))
            
            TextField("share.notePlaceholder".shareLocalized, text: $userNote, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1...3)
        }
        .padding(12)
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(12)
    }
    
    private var collectionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("share.collection.title".shareLocalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if !isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                        Text("PRO")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "None" or "Inbox"
                    Button {
                        selectedCollection = nil
                    } label: {
                        Text("share.collection.none".shareLocalized)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCollection == nil ? Color(hex: "#CCFF00") : Color(hex: "#2C2C2E"))
                            .foregroundColor(selectedCollection == nil ? .black : .white)
                            .cornerRadius(8)
                    }
                    .disabled(!isPro)
                    .opacity(isPro ? 1.0 : 0.5)
                    
                    ForEach(collections) { collection in
                        Button {
                            selectedCollection = collection
                        } label: {
                            HStack(spacing: 4) {
                                Text(collection.emoji ?? "📁")
                                Text(collection.name)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCollection?.id == collection.id ? Color(hex: "#CCFF00") : Color(hex: "#2C2C2E"))
                            .foregroundColor(selectedCollection?.id == collection.id ? .black : .white)
                            .cornerRadius(8)
                        }
                        .disabled(!isPro)
                        .opacity(isPro ? 1.0 : 0.5)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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
                
                Text("shareExtension.saved".shareLocalized)
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
        
        let finalScheduledFor = scheduledFor ?? Date()
        
        // v2.1 DOZ: Intent basit - sadece uyumluluk için
        // Artık scheduledFor tek önemli alan
        let intent: BookmarkIntent = finalScheduledFor.timeIntervalSinceNow < 60 ? .now : .tomorrow
        
        // Expiration logic moved to Bookmark model
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                // Update existing bookmark
                existing.createdAt = Date()
                existing.scheduledFor = finalScheduledFor
                existing.userNote = userNote.isEmpty ? nil : userNote
                
                existing.intent = intent
                existing.expiresAt = intent.calculateExpiresAt(from: finalScheduledFor, isPro: isPro)
                existing.collection = selectedCollection
                
                // v2.1 Logic Fix: ALWAYS reset status for existing items when "pulling forward"
                // or rescheduling. This brings "archived/history" items back to Focus.
                existing.status = .active
                existing.archivedAt = nil
                existing.archivedReason = nil
                existing.readAt = nil
                existing.lastScrollPercentage = 0
                // We keep contentHTML and others to avoid re-fetching if possible
            } else {
                // Create new bookmark with v2.1 DOZ fields
                let bookmark = Bookmark(
                    userID: userID,
                    originalURL: url,
                    status: .active,
                    scheduledFor: finalScheduledFor,
                    title: metadataLoader.title ?? domain,
                    type: detectBookmarkType(),
                    domain: URL(string: url)?.host ?? "unknown",
                    userNote: userNote.isEmpty ? nil : userNote,
                    expiresAt: intent.calculateExpiresAt(from: finalScheduledFor, isPro: isPro),
                    intent: intent,
                    // v3.1 Enrichment: Force enrichment for raw links from share extension
                    needsEnrichment: true,
                    enrichmentStatus: .pending,
                    collection: selectedCollection
                )
                modelContext.insert(bookmark)
            }
            
            try modelContext.save()
            
            // Trigger sync
            defaults?.set(true, forKey: "needsSync")
        } catch {
            print("❌ Failed to save bookmark: \(error)")
        }
    }
    
    private var calendar: Calendar { Calendar.current }
    
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
                return "share.time.thisMorning".shareLocalized
            } else if hour < 17 {
                return "share.time.thisAfternoon".shareLocalized
            } else {
                return "share.time.tonight".shareLocalized(with: timeString)
            }
        } else if calendar.isDateInTomorrow(date) {
            return "share.time.tomorrow".shareLocalized(with: timeString)
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "tr_TR")
            dayFormatter.dateFormat = "EEEE"
            return "share.time.day".shareLocalized(with: dayFormatter.string(from: date), timeString)
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

// MARK: - v2.1 DOZ Dose Button

struct DoseButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8E8E93"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(Color(hex: "#1C1C1E"))
            .cornerRadius(16)
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


