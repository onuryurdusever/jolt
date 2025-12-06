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
    var metadata: [String: String]? // Platform specific data (e.g. videoId, author, stars)
    
    @Attribute(.preserveValueOnDeletion)
    var isStarred: Bool? // Favorite bookmark - optional for migration
    
    @Relationship(deleteRule: .nullify)
    var collection: Collection?
    
    // v3.0 Parser fields
    var isProtected: Bool? // Content requires authentication (Notion, Jira, etc.)
    var isPaywalled: Bool? // Content is behind paywall (Medium, Substack premium)
    var fetchMethod: String? // 'api', 'oembed', 'readability', 'meta-only', 'webview'
    var parseConfidence: Double? // 0.0-1.0 quality score
    
    init(
        id: UUID = UUID(),
        userID: String,
        originalURL: String,
        status: BookmarkStatus = .pending,
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
        metadata: [String: String]? = nil,
        isStarred: Bool? = false,
        collection: Collection? = nil,
        isProtected: Bool? = nil,
        isPaywalled: Bool? = nil,
        fetchMethod: String? = nil,
        parseConfidence: Double? = nil
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
        self.metadata = metadata
        self.isStarred = isStarred ?? false
        self.collection = collection
        self.isProtected = isProtected
        self.isPaywalled = isPaywalled
        self.fetchMethod = fetchMethod
        self.parseConfidence = parseConfidence
    }
}

enum BookmarkStatus: String, Codable {
    case pending   // Waiting for backend parse
    case ready     // Parsed and ready to read
    case archived  // Completed/jolted
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
}
