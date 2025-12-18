//
//  Bookmark.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var userID: String
    var originalURL: String
    var status: BookmarkStatus
    var scheduledFor: Date // UTC timestamp
    var contentHTML: String?
    var title: String
    var excerpt: String?
    var coverImage: String?
    var readingTimeMinutes: Int
    var type: BookmarkType
    var domain: String
    var createdAt: Date
    var readAt: Date?
    var userNote: String? // User's personal note/context for saving
    var lastScrollPercentage: Double? // 0.0 to 1.0
    var lastScrollY: Double? // Absolute scroll position (pixels)
    var metadata: [String: String]? // Platform specific data (e.g. videoId, author, stars)
    
    @Attribute(.preserveValueOnDeletion)
    var isStarred: Bool? // Favorite bookmark - optional for migration
    
    // v3.0 Parser fields
    var isProtected: Bool? // Content requires authentication (Notion, Jira, etc.)
    var isPaywalled: Bool? // Content is behind paywall (Medium, Substack premium)
    var fetchMethod: String? // 'api', 'oembed', 'readability', 'meta-only', 'webview'
    var parseConfidence: Double? // 0.0-1.0 quality score
    
    // v2.1 Expiration Engine fields
    var expiresAt: Date? // TTL - auto-archive date (default: createdAt + 7 days)
    var archivedAt: Date? // When bookmark was archived (soft delete)
    var archivedReason: String? // 'completed', 'manual', 'auto' (expired)
    var recoveredAt: Date? // If user recovered from archive
    var snoozeCount: Int? // Track snoozes for scoring
    var intent: BookmarkIntent? // When user plans to read: now, tonight, weekend
    var lastVideoPosition: Int? // Video resume position in seconds
    var webviewReason: String? // Reason for falling back to webview (e.g. spa_forced, requires_javascript)
    
    // v3.1 Enrichment Pipeline fields
    var needsEnrichment: Bool = false
    var enrichmentStatus: EnrichmentStatus = EnrichmentStatus.done // Default to done to avoid reprocessing
    var enrichmentAttempts: Int = 0
    var enrichmentNextAttemptAt: Date? = nil
    
    // v3.2 Collections (Pro)
    var collection: JoltCollection?
    
    init(
        id: UUID = UUID(),
        userID: String,
        originalURL: String,
        status: BookmarkStatus = .active,
        scheduledFor: Date,
        contentHTML: String? = nil,
        title: String,
        excerpt: String? = nil,
        coverImage: String? = nil,
        readingTimeMinutes: Int = 0,
        type: BookmarkType = .article,
        domain: String,
        createdAt: Date = Date(),
        readAt: Date? = nil,
        userNote: String? = nil,
        lastScrollPercentage: Double? = nil,
        lastScrollY: Double? = nil,
        metadata: [String: String]? = nil,
        isStarred: Bool? = false,
        isProtected: Bool? = nil,
        isPaywalled: Bool? = nil,
        fetchMethod: String? = nil,
        parseConfidence: Double? = nil,
        expiresAt: Date? = nil,
        archivedAt: Date? = nil,
        archivedReason: String? = nil,
        recoveredAt: Date? = nil,
        snoozeCount: Int? = 0,
        intent: BookmarkIntent? = nil,
        lastVideoPosition: Int? = nil,
        webviewReason: String? = nil,
        // v3.1 Enrichment
        needsEnrichment: Bool = false,
        enrichmentStatus: EnrichmentStatus = .done,
        enrichmentAttempts: Int = 0,
        enrichmentNextAttemptAt: Date? = nil,
        // v3.2 Collections
        collection: JoltCollection? = nil
    ) {
        self.id = id
        self.userID = userID
        self.originalURL = originalURL
        self.status = status
        self.scheduledFor = scheduledFor
        self.contentHTML = contentHTML
        self.title = title
        self.excerpt = excerpt
        self.coverImage = coverImage
        self.readingTimeMinutes = readingTimeMinutes
        self.type = type
        self.domain = domain
        self.createdAt = createdAt
        self.readAt = readAt
        self.userNote = userNote
        self.lastScrollPercentage = lastScrollPercentage
        self.lastScrollY = lastScrollY
        self.metadata = metadata
        self.isStarred = isStarred ?? false
        self.isProtected = isProtected
        self.isPaywalled = isPaywalled
        self.fetchMethod = fetchMethod
        self.parseConfidence = parseConfidence
        
        // v2.1 Expiration fields
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .day, value: 7, to: createdAt)
        self.archivedAt = archivedAt
        self.archivedReason = archivedReason
        self.recoveredAt = recoveredAt
        self.snoozeCount = snoozeCount ?? 0
        self.intent = intent
        self.lastVideoPosition = lastVideoPosition
        self.webviewReason = webviewReason
        
        self.needsEnrichment = needsEnrichment
        self.enrichmentStatus = enrichmentStatus
        self.enrichmentAttempts = enrichmentAttempts
        self.enrichmentNextAttemptAt = enrichmentNextAttemptAt
        
        // v3.2 Collections
        self.collection = collection
        
        // Finalize expiresAt if not set
        if self.expiresAt == nil {
            let isPro = UserDefaults(suiteName: "group.com.jolt.shared")?.bool(forKey: "is_pro") ?? false
            self.expiresAt = self.intent?.calculateExpiresAt(from: createdAt, isPro: isPro) 
                ?? Calendar.current.date(byAdding: .day, value: 7, to: createdAt)
        }
    }
}

enum BookmarkStatus: String, Codable {
    case active    // v2.1: Active content (was pending/ready)
    case completed // User finished reading/watching
    case archived  // Soft deleted (manual or auto-expired)
    case expired   // Auto-archived due to TTL (30 days then hard delete)
    
    // Custom decoding to handle migration from old values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "active":
            self = .active
        case "completed":
            self = .completed
        case "archived":
            self = .archived
        case "expired":
            self = .expired
        // Migration: Map old values to new
        case "pending", "ready":
            self = .active
        default:
            self = .active // Default fallback
        }
    }
}
    
enum EnrichmentStatus: String, Codable {
    case pending     // Needs processing
    case inProgress  // Currently being processed
    case done        // Successfully processed
    case failed      // Processing failed (will retry)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EnrichmentStatus(rawValue: rawValue) ?? .pending
    }
}

/// v2.0: User's delivery timing choice - "Ne Zaman?" (When?)
/// Replaced "Rutin" concept with simple delivery timing
enum BookmarkIntent: String, Codable {
    case now      // ⚡️ Şimdi - Add to top, read immediately
    case tomorrow // ☀️ Yarına/Sabaha - Next delivery slot (morning or evening)
    case weekend  // 📅 Hafta Sonu - Locked until Friday 18:00
    
    var displayName: String {
        switch self {
        case .now: return "intent.now".localized
        case .tomorrow: return smartTomorrowLabel
        case .weekend: return "intent.weekend".localized
        }
    }
    
    /// Dynamic label: "Bugün Akşama" before noon, "Yarına" after noon
    private var smartTomorrowLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "intent.tonight".localized : "intent.tomorrow".localized
    }
    
    var subtitle: String {
        switch self {
        case .now: return "intent.now.subtitle".localized
        case .tomorrow: return "intent.tomorrow.subtitle".localized
        case .weekend: return "intent.weekend.subtitle".localized
        }
    }
    
    var icon: String {
        switch self {
        case .now: return "bolt.fill"
        case .tomorrow: return "sun.max.fill"
        case .weekend: return "calendar"
        }
    }
    
    /// Calculate scheduledFor date based on intent and delivery times
    nonisolated func calculateScheduledDate(from date: Date = Date(), morningHour: Int = 8, morningMinute: Int = 30, eveningHour: Int = 21, eveningMinute: Int = 0) -> Date {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        
        switch self {
        case .now:
            return date // Immediate - top of list
            
        case .tomorrow:
            // Smart delivery: morning or evening slot
            if currentHour < 12 {
                // Before noon → deliver tonight
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = eveningHour
                components.minute = eveningMinute
                if let tonight = calendar.date(from: components), tonight > date {
                    return tonight
                }
            }
            // After noon or past evening → deliver tomorrow morning
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = morningHour
            components.minute = morningMinute
            return calendar.date(from: components)!
            
        case .weekend:
            // Next Friday at 18:00 (locked until then)
            let weekday = calendar.component(.weekday, from: date)
            let daysUntilFriday = (6 - weekday + 7) % 7 // Friday is 6 (Sun=1, Mon=2, ..., Fri=6, Sat=7)
            let nextFriday = calendar.date(byAdding: .day, value: daysUntilFriday == 0 ? 7 : daysUntilFriday, to: date)!
            var components = calendar.dateComponents([.year, .month, .day], from: nextFriday)
            components.hour = 18
            components.minute = 0
            return calendar.date(from: components)!
        }
    }
    
    /// Calculate expiresAt based on intent (7-30 days for pro, 7 for free)
    nonisolated func calculateExpiresAt(from date: Date = Date(), isPro: Bool = false) -> Date {
        let days = isPro ? (UserDefaults(suiteName: "group.com.jolt.shared")?.integer(forKey: "pro_expire_days") ?? 7) : 7
        // Ensure days is at least 7
        let effectiveDays = max(7, days)
        let scheduledDate = calculateScheduledDate(from: date)
        return Calendar.current.date(byAdding: .day, value: effectiveDays, to: scheduledDate)!
    }
    
    /// Check if content is locked (weekend items before Friday)
    var isLocked: Bool {
        guard self == .weekend else { return false }
        let scheduledDate = calculateScheduledDate()
        return Date() < scheduledDate
    }
}

enum BookmarkType: String, Codable, CaseIterable {
    case article   // Clean text parsed by Readability
    case webview   // Fallback - show in WebView
    case video     // YouTube, Vimeo etc
    case social    // Twitter, Instagram etc
    case pdf       // PDF Document
    case audio     // Spotify, Apple Music, SoundCloud
    case code      // GitHub, StackOverflow
    case product   // AppStore, ProductHunt
    case map       // Google Maps
    case design    // Figma, Dribbble, Behance
    
    var displayName: String {
        switch self {
        case .article: return "Articles"
        case .webview: return "Web"
        case .video: return "Videos"
        case .social: return "Social"
        case .pdf: return "PDFs"
        case .audio: return "Audio"
        case .code: return "Code"
        case .product: return "Products"
        case .map: return "Maps"
        case .design: return "Design"
        }
    }
    
    var icon: String {
        switch self {
        case .article: return "doc.text.fill"
        case .webview: return "globe"
        case .video: return "play.rectangle.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .pdf: return "doc.fill"
        case .audio: return "headphones"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .product: return "bag.fill"
        case .map: return "map.fill"
        case .design: return "paintbrush.fill"
        }
    }
    
    var color: String {
        switch self {
        case .article: return "#4A90D9"
        case .webview: return "#8E8E93"
        case .video: return "#FF3B30"
        case .social: return "#FF9500"
        case .pdf: return "#FF2D55"
        case .audio: return "#AF52DE"
        case .code: return "#34C759"
        case .product: return "#5AC8FA"
        case .map: return "#007AFF"
        case .design: return "#FF6B6B"
        }
    }
}

extension Bookmark {
    var isPDF: Bool {
        return type == .pdf || originalURL.lowercased().hasSuffix(".pdf")
    }
    
    /// Content requires WebView due to protection or low parse confidence
    var requiresWebView: Bool {
        if type == .webview { return true }
        if isProtected == true { return true }
        if isPaywalled == true { return true }
        if fetchMethod == "webview" || fetchMethod == "meta-only" { return true }
        if let confidence = parseConfidence, confidence < 0.3 { return true }
        return false
    }
    
    /// Show paywall indicator in UI
    var showPaywallBadge: Bool {
        return isPaywalled == true
    }
    
    /// Show protected indicator in UI
    var showProtectedBadge: Bool {
        return isProtected == true
    }
    
    /// Generate favicon URL using Google Favicon API as fallback when no cover image
    var faviconURL: URL? {
        // Use the domain directly, or extract from originalURL
        let domainToUse: String
        if domain.isEmpty || domain == "Jolt" {
            // Internal/tutorial content - no favicon needed
            return nil
        } else if let url = URL(string: originalURL), let host = url.host {
            domainToUse = host
        } else {
            domainToUse = domain
        }
        
        // Google Favicon API - returns 64x64 favicon
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domainToUse)&sz=128")
    }
    
    /// Returns cover image URL, or favicon URL as fallback
    var displayImageURL: URL? {
        if let coverImageStr = coverImage, !coverImageStr.isEmpty, let url = URL(string: coverImageStr) {
            return url
        }
        return faviconURL
    }
    
    /// Check if we should show favicon (small icon) vs cover image (large image)
    var shouldShowFaviconFallback: Bool {
        return coverImage == nil || coverImage?.isEmpty == true
    }
    
    var platformIcon: String? {
        let domain = self.domain.lowercased()
        if domain.contains("twitter.com") || domain.contains("x.com") { return "xmark.app.fill" }
        if domain.contains("instagram.com") { return "camera.fill" }
        if domain.contains("tiktok.com") { return "music.note" }
        if domain.contains("youtube.com") { return "play.rectangle.fill" }
        if domain.contains("facebook.com") { return "person.2.fill" }
        if domain.contains("linkedin.com") { return "briefcase.fill" }
        if domain.contains("medium.com") { return "doc.text.fill" }
        if domain.contains("github.com") { return "chevron.left.forwardslash.chevron.right" }
        return nil
    }
    
    var platformName: String {
        return self.domain
    }
    
    // MARK: - v2.1 Expiration Engine Helpers
    
    /// Time remaining until expiration
    var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSince(Date())
    }
    
    /// Days remaining until expiration
    var daysUntilExpiration: Int? {
        guard let timeRemaining = timeUntilExpiration else { return nil }
        return max(0, Int(ceil(timeRemaining / 86400)))
    }
    
    /// Hours remaining until expiration (for <24h display)
    var hoursUntilExpiration: Int? {
        guard let timeRemaining = timeUntilExpiration else { return nil }
        return max(0, Int(ceil(timeRemaining / 3600)))
    }
    
    /// Expiration urgency level for UI styling
    var expirationUrgency: ExpirationUrgency {
        // Red check: Less than 1 hour (3600 seconds)
        if let timeRemaining = timeUntilExpiration, timeRemaining < 3600 {
            return .critical
        }
        
        guard let days = daysUntilExpiration else { return .safe }
        switch days {
        case 0: return .urgent   // <24 hours but > 1 hour (Orange)
        case 1: return .warning  // 1 day (Yellow)
        case 2...3: return .warning // 2-3 days (Yellow)
        default: return .safe    // 4+ days (Green)
        }
    }
    
    /// Formatted countdown string
    var countdownText: String {
        guard let days = daysUntilExpiration else { return "" }
        
        if days == 0 {
            if let hours = hoursUntilExpiration {
                if hours <= 1 {
                    return "expire.archiving".localized
                }
                return "expire.hoursLeft".localized(with: hours)
            }
        } else if days == 1 {
            return "expire.lastDay".localized
        } else {
            return "expire.daysLeft".localized(with: days)
        }
        return ""
    }
    
    /// Progress percentage for countdown bar (1.0 = full time, 0.0 = expired)
    var countdownProgress: Double {
        guard let expiresAt = expiresAt else { return 1.0 }
        let totalDuration: TimeInterval = 7 * 24 * 3600 // 7 days default
        let remaining = expiresAt.timeIntervalSince(Date())
        return max(0, min(1, remaining / totalDuration))
    }
    
    /// Check if bookmark is expired (past expiresAt date)
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// Check if bookmark should be hard deleted (30 days after archive)
    var shouldHardDelete: Bool {
        guard let archivedAt = archivedAt else { return false }
        let daysSinceArchive = Calendar.current.dateComponents([.day], from: archivedAt, to: Date()).day ?? 0
        return daysSinceArchive >= 30
    }
    
    /// Days until hard delete (for UI display)
    var daysUntilHardDelete: Int? {
        guard let archivedAt = archivedAt else { return nil }
        let daysSinceArchive = Calendar.current.dateComponents([.day], from: archivedAt, to: Date()).day ?? 0
        return max(0, 30 - daysSinceArchive)
    }
    
    /// Check if bookmark can be recovered (within 30 days of archive)
    var canRecover: Bool {
        guard status == .archived || status == .expired else { return false }
        guard let daysLeft = daysUntilHardDelete else { return false }
        return daysLeft > 0
    }
    
    // MARK: - v2.1 Actions
    
    /// Mark as completed (user finished reading)
    func markCompleted() {
        print("✅ MARKING COMPLETED: \(self.title) (ID: \(self.id))")
        self.status = .completed
        self.readAt = Date()
        self.archivedAt = Date()
        self.archivedReason = "completed"
    }
    
    /// Archive manually (user closed)
    func archiveManually() {
        self.status = .archived
        self.archivedAt = Date()
        self.archivedReason = "manual"
    }
    
    /// Archive due to expiration (auto)
    func archiveExpired() {
        self.status = .expired
        self.archivedAt = Date()
        self.archivedReason = "auto"
    }
    
    /// Burn manually (user swipe action)
    func burn() {
        self.status = .expired
        self.archivedAt = Date()
        self.archivedReason = "manual"
    }
    
    /// Recover from archive
    func recover(isPro: Bool = false) {
        self.status = .active
        self.archivedAt = nil
        self.archivedReason = nil
        self.recoveredAt = Date()
        // Reset expiration with new 7/14 day window
        self.expiresAt = Calendar.current.date(byAdding: .day, value: isPro ? 14 : 7, to: Date())
    }
    
    /// Snooze bookmark to new time
    func snooze(to intent: BookmarkIntent, isPro: Bool = false) {
        self.intent = intent
        self.scheduledFor = intent.calculateScheduledDate()
        self.expiresAt = intent.calculateExpiresAt(isPro: isPro)
        self.snoozeCount = (self.snoozeCount ?? 0) + 1
    }
}

/// Expiration urgency levels for UI styling
enum ExpirationUrgency {
    case safe      // 4+ days (green)
    case warning   // 2-3 days (yellow)
    case urgent    // 1 day (orange)
    case critical  // <24 hours (red, pulsing)
    
    var colorHex: String {
        switch self {
        case .safe: return "#34C759"     // Green
        case .warning: return "#FFD60A"  // Yellow
        case .urgent: return "#FF9F0A"   // Orange
        case .critical: return "#FF3B30" // Red
        }
    }
    
    var shouldPulse: Bool {
        return self == .critical || self == .urgent
    }
}
