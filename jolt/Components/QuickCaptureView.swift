//
//  QuickCaptureView.swift
//  jolt
//
//  Shared component for quick link capture - used by both Share Extension and Main App
//  Created by Onur Yurdusever on 4.12.2025.
//  v2.1 - Matched with ShareExtension design (DOZ system)
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
    
    func cancel() {
        loadTask?.cancel()
    }
}

// MARK: - Quick Capture View (Main App - Clipboard)

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
    
    // Metadata
    @StateObject private var metadataLoader = LinkMetadataLoader()
    
    // UI State
    @State private var userNote: String = ""
    @State private var showSuccess = false
    @State private var isDuplicate = false
    
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
    
    private var isPremium: Bool {
        defaults?.bool(forKey: "isPremium") ?? false
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
                        
                        // v2.1 DOZ Sistemi: Basit 3 seçenek (ShareExtension ile aynı)
                        doseSelectionButtons
                            .padding(.horizontal, 20)
                        
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
                        .overlay(ShimmerView().clipShape(RoundedRectangle(cornerRadius: 12)))
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
                        .overlay(ShimmerView().clipShape(RoundedRectangle(cornerRadius: 4)))
                    
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
    
    // MARK: - v2.1 DOZ Seçim Butonları (ShareExtension ile birebir aynı)
    
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
                    Text(isDuplicate ? "shareExtension.bumpToTop".localized : "shareExtension.readNow".localized)
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
            return "shareExtension.toMorning".localized
        }
        
        let morningTime = calendar.date(bySettingHour: morning.hour, minute: morning.minute, second: 0, of: now) ?? now
        
        if morningTime > now {
            return "shareExtension.toMorning".localized
        } else {
            return "shareExtension.tomorrowMorning".localized
        }
    }
    
    private var eveningDoseLabel: String {
        let calendar = Calendar.current
        let now = Date()
        
        guard let evening = eveningRoutine else {
            return "shareExtension.toEvening".localized
        }
        
        let eveningTime = calendar.date(bySettingHour: evening.hour, minute: evening.minute, second: 0, of: now) ?? now
        
        if eveningTime > now {
            return "shareExtension.toEvening".localized
        } else {
            return "shareExtension.tomorrowEvening".localized
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
            
            TextField("share.notePlaceholder".localized, text: $userNote, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1...3)
        }
        .padding(12)
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(12)
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
        
        withAnimation {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            clearDraft()
            onComplete(.saved)
        }
    }
    
    private func performSave(scheduledFor: Date?) {
        let context = effectiveModelContext
        let userId = effectiveUserID
        let calendar = Calendar.current
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.originalURL == url && bookmark.userID == userId
            }
        )
        
        let finalScheduledFor = scheduledFor ?? Date()
        
        // v2.1 DOZ: Intent basit
        let intent: BookmarkIntent = finalScheduledFor.timeIntervalSinceNow < 60 ? .now : .tomorrow
        
        // Expiration: Premium 30 gün, Free 7 gün
        let expiresAt = calendar.date(byAdding: .day, value: isPremium ? 30 : 7, to: Date())
        
        do {
            if let existing = try context.fetch(descriptor).first {
                // Update existing bookmark
                existing.createdAt = Date()
                existing.scheduledFor = finalScheduledFor
                existing.userNote = userNote.isEmpty ? nil : userNote
                existing.intent = intent
                existing.expiresAt = expiresAt
                
                // Reset status for existing items
                existing.status = .active
                existing.archivedAt = nil
                existing.archivedReason = nil
                existing.readAt = nil
                existing.lastScrollPercentage = 0
            } else {
                // Create new bookmark
                let bookmark = Bookmark(
                    userID: userId,
                    originalURL: url,
                    status: .active,
                    scheduledFor: finalScheduledFor,
                    title: metadataLoader.title ?? domain,
                    type: detectBookmarkType(),
                    domain: URL(string: url)?.host ?? "unknown",
                    userNote: userNote.isEmpty ? nil : userNote,
                    expiresAt: expiresAt,

                    intent: intent,
                    // v3.1 Enrichment: Force enrichment for clipboard items
                    needsEnrichment: true,
                    enrichmentStatus: .pending
                )
                context.insert(bookmark)
            }
            
            try context.save()
            
            // Trigger sync for main app
            if source == .clipboard {
                defaults?.set(true, forKey: "needsSync")
                Task {
                    await EnrichmentService.shared.processPendingEnrichments(context: context)
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

// MARK: - Dose Button (ShareExtension ile aynı)

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
    .modelContainer(for: [Bookmark.self, Routine.self], inMemory: true)
}
