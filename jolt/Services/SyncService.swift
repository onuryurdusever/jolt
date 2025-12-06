//
//  SyncService.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation
import SwiftData
import Combine

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing = false
    @Published var syncProgress: String = ""  // For UI feedback
    @Published var lastSyncDate: Date?
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        // Check for pending offline actions when sync service initializes
        // This will be called when app starts
        
        // Listen for internet restoration
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(internetRestored),
            name: NSNotification.Name("InternetRestored"),
            object: nil
        )
    }
    
    @objc private func internetRestored() {
        print("📡 Internet restored notification received")
        Task {
            // Will sync with context when user interacts with the app
            // Alternatively, can fetch context from SwiftData somehow
        }
    }
    
    // MARK: - Offline Action Logging
    
    /// Log an offline action when internet is unavailable
    func logOfflineAction(_ actionType: SyncActionType, for targetID: UUID, context: ModelContext) {
        let action = SyncAction(
            actionType: actionType,
            targetID: targetID,
            timestamp: Date(),
            isProcessed: false
        )
        
        context.insert(action)
        
        do {
            try context.save()
            print("📝 Offline action logged: \(actionType.rawValue) for \(targetID)")
        } catch {
            print("❌ Failed to log offline action: \(error)")
        }
    }
    
    /// Process pending offline actions when internet becomes available
    func processPendingOfflineActions(context: ModelContext) async {
        print("🔄 Processing pending offline actions...")
        
        do {
            // Fetch unprocessed actions
            var descriptor = FetchDescriptor<SyncAction>(
                predicate: #Predicate { action in
                    !action.isProcessed
                }
            )
            descriptor.sortBy = [SortDescriptor(\.timestamp)]
            
            let pendingActions = try context.fetch(descriptor)
            
            guard !pendingActions.isEmpty else {
                print("✅ No pending offline actions")
                return
            }
            
            print("📋 Found \(pendingActions.count) pending offline actions")
            
            // Process actions in order (oldest first)
            for action in pendingActions {
                print("⏳ Processing: \(action.actionType.rawValue) for \(action.targetID)")
                
                // Simulate server sync (in production, send to backend)
                let success = await syncActionToServer(action)
                
                if success {
                    action.isProcessed = true
                    try context.save()
                    print("✅ Action processed: \(action.actionType.rawValue)")
                } else {
                    print("⚠️ Failed to process action, will retry next time")
                    break  // Stop processing, will retry later
                }
            }
            
            print("✅ Offline actions queue processed")
            
        } catch {
            print("❌ Failed to process offline actions: \(error)")
        }
    }
    
    /// Simulate sending action to server (in production, implement actual API call)
    private func syncActionToServer(_ action: SyncAction) async -> Bool {
        // Simulate network request
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
        
        print("📡 Syncing action to server: \(action.actionType.rawValue)")
        // In production, implement actual Supabase API call here
        // For now, simulate success
        return true
    }
    
    func syncPendingBookmarks(context: ModelContext) async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }
        
        isSyncing = true
        syncProgress = "Syncing..."
        defer { 
            isSyncing = false
            syncProgress = ""
        }
        
        do {
            // Query all bookmarks and filter for pending
            let descriptor = FetchDescriptor<Bookmark>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            
            let allBookmarks = try context.fetch(descriptor)
            print("📊 Total bookmarks in DB: \(allBookmarks.count)")
            
            let pendingBookmarks = allBookmarks.filter { $0.status == .pending }
            print("📊 Pending bookmarks: \(pendingBookmarks.count)")
            
            // Debug: print all bookmark statuses
            for bookmark in allBookmarks {
                print("📖 Bookmark: \(bookmark.title) - Status: \(bookmark.status.rawValue) - URL: \(bookmark.originalURL)")
            }
            
            guard !pendingBookmarks.isEmpty else {
                print("✅ No pending bookmarks to sync")
                lastSyncDate = Date()
                return
            }
            
            print("🔄 Syncing \(pendingBookmarks.count) pending bookmarks...")
            syncProgress = "Parsing \(pendingBookmarks.count) items..."
            
            // Process in batches with concurrency limit
            await withTaskGroup(of: (Bookmark, ParsedContent?).self) { group in
                var processed = 0
                
                for bookmark in pendingBookmarks {
                    // Limit concurrent requests
                    if processed >= Config.maxConcurrentRequests {
                        // Wait for one to complete
                        if let result = await group.next() {
                            updateBookmark(result.0, with: result.1, context: context)
                        }
                        processed -= 1
                    }
                    
                    group.addTask {
                        let parsed = await self.parseURL(bookmark.originalURL)
                        return (bookmark, parsed)
                    }
                    processed += 1
                }
                
                // Process remaining results
                for await result in group {
                    updateBookmark(result.0, with: result.1, context: context)
                }
            }
            
            // Save changes
            try context.save()
            
            // Process pending collection assignments
            processPendingCollections(context: context)
            
            lastSyncDate = Date()
            
            print("✅ Sync complete: \(pendingBookmarks.count) bookmarks processed")
            
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }
    
    private func processPendingCollections(context: ModelContext) {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jolt.shared") else {
            print("❌ Failed to get App Group container")
            return
        }
        
        let fileURL = appGroupURL.appendingPathComponent("pendingCollections.json")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("✅ No pending collections to process")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let pendingCollections = try JSONDecoder().decode([String: String].self, from: data)
            
            let bookmarkDescriptor = FetchDescriptor<Bookmark>()
            let allBookmarks = try context.fetch(bookmarkDescriptor)
            
            let collectionDescriptor = FetchDescriptor<Collection>()
            let allCollections = try context.fetch(collectionDescriptor)
            
            for (bookmarkIDString, collectionIDString) in pendingCollections {
                guard let bookmarkID = UUID(uuidString: bookmarkIDString),
                      let collectionID = UUID(uuidString: collectionIDString),
                      let bookmark = allBookmarks.first(where: { $0.id == bookmarkID }),
                      let collection = allCollections.first(where: { $0.id == collectionID }) else {
                    continue
                }
                
                bookmark.collection = collection
                print("✅ Assigned bookmark \(bookmark.title) to collection \(collection.name)")
            }
            
            try context.save()
            
            // Clear the file after processing
            try? FileManager.default.removeItem(at: fileURL)
            print("✅ Processed \(pendingCollections.count) pending collection assignments")
            
        } catch {
            print("❌ Failed to process pending collections: \(error)")
        }
    }
    
    private func parseURL(_ url: String) async -> ParsedContent? {
        do {
            let apiURL = Config.Endpoint.parse.url
            
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.timeoutInterval = Config.requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let body: [String: Any] = [
                "url": url,
                "user_id": AuthService.shared.currentUserID ?? ""
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let parsed = try JSONDecoder().decode(ParsedContent.self, from: data)
            return parsed
            
        } catch {
            print("❌ Failed to parse \(url): \(error)")
            return nil
        }
    }
    
    private func updateBookmark(_ bookmark: Bookmark, with parsed: ParsedContent?, context: ModelContext) {
        // Check if it's a social media URL
        let domain = URL(string: bookmark.originalURL)?.host?.lowercased() ?? ""
        let isSocialMedia = domain.contains("twitter.com") || domain.contains("x.com") || 
                           domain.contains("instagram.com") || domain.contains("tiktok.com") ||
                           domain.contains("youtube.com") || domain.contains("facebook.com")
        
        if isSocialMedia {
            // For social media, use minimal parsing or fallback
            if let parsed = parsed, !parsed.title.isEmpty {
                bookmark.title = parsed.title
                bookmark.excerpt = parsed.excerpt
                bookmark.coverImage = parsed.cover_image
                bookmark.readingTimeMinutes = parsed.reading_time_minutes
                // v3.0 fields
                bookmark.isProtected = parsed.protected
                bookmark.isPaywalled = parsed.paywalled
                bookmark.fetchMethod = parsed.fetchMethod
                bookmark.parseConfidence = parsed.confidence
            } else {
                // Fallback: extract from URL
                bookmark.title = extractSocialMediaTitle(from: bookmark.originalURL, domain: domain)
                bookmark.readingTimeMinutes = 2 // Default for social
                bookmark.fetchMethod = "meta-only"
                bookmark.parseConfidence = 0.3
            }
            bookmark.type = .social
            bookmark.contentHTML = nil // Force webview
        } else if let parsed = parsed {
            // Normal article/website parsing
            bookmark.title = parsed.title.isEmpty ? SyncService.shared.extractTitleFromURL(bookmark.originalURL) : parsed.title
            bookmark.excerpt = parsed.excerpt
            bookmark.contentHTML = parsed.content_html
            bookmark.coverImage = parsed.cover_image
            bookmark.readingTimeMinutes = parsed.reading_time_minutes
            
            // v3.0 fields
            bookmark.isProtected = parsed.protected
            bookmark.isPaywalled = parsed.paywalled
            bookmark.fetchMethod = parsed.fetchMethod
            bookmark.parseConfidence = parsed.confidence
            
            // Determine type based on parsed response
            let parsedType = BookmarkType(rawValue: parsed.type) ?? .webview
            
            // Force webview for protected/paywalled or low confidence content
            if parsed.protected == true || parsed.paywalled == true {
                bookmark.type = parsedType == .video ? .video : .webview
            } else if let confidence = parsed.confidence, confidence < 0.3 {
                bookmark.type = .webview
            } else {
                bookmark.type = parsedType
            }
        } else {
            // Keep as pending if parse failed (will retry next sync)
            return
        }
        
        bookmark.domain = URL(string: bookmark.originalURL)?.host ?? domain
        bookmark.status = .ready
        
        // Index in Spotlight for search
        SpotlightService.shared.indexBookmark(bookmark)
        
        print("✅ Updated bookmark: \(bookmark.title) (method: \(bookmark.fetchMethod ?? "unknown"), confidence: \(String(format: "%.2f", bookmark.parseConfidence ?? 0)))")
    }
    
    private func extractSocialMediaTitle(from url: String, domain: String) -> String {
        if domain.contains("twitter.com") || domain.contains("x.com") {
            return "X Post"
        } else if domain.contains("instagram.com") {
            return "Instagram Post"
        } else if domain.contains("tiktok.com") {
            return "TikTok Video"
        } else if domain.contains("youtube.com") {
            return "YouTube Video"
        } else if domain.contains("facebook.com") {
            return "Facebook Post"
        }
        return "Social Media Post"
    }
    
    func extractTitleFromURL(_ url: String) -> String {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return url
        }
        
        // Get the last path component (slug)
        let pathComponents = urlObj.pathComponents.filter { $0 != "/" }
        guard let slug = pathComponents.last else {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        
        // Remove file extensions
        let cleanSlug = slug.replacingOccurrences(of: ".html", with: "")
                            .replacingOccurrences(of: ".php", with: "")
                            .replacingOccurrences(of: ".aspx", with: "")
        
        // Replace hyphens and underscores with spaces
        let withSpaces = cleanSlug.replacingOccurrences(of: "-", with: " ")
                                   .replacingOccurrences(of: "_", with: " ")
        
        // Capitalize each word (Title Case)
        let titleCased = withSpaces.split(separator: " ")
                                   .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                                   .joined(separator: " ")
        
        return titleCased
    }
}

// MARK: - Models

struct ParsedContent: Codable {
    let success: Bool?
    let type: String
    let title: String
    let excerpt: String?
    let content_html: String?
    let cover_image: String?
    let reading_time_minutes: Int
    let domain: String
    let cached: Bool?
    // v3.0 fields
    let protected: Bool?       // Content requires authentication
    let paywalled: Bool?       // Content is behind paywall
    let fetchMethod: String?   // 'api', 'oembed', 'readability', 'meta-only', 'webview'
    let confidence: Double?    // 0.0-1.0 parse quality score
    let error: ParseError?     // Error details if parsing failed
    
    enum CodingKeys: String, CodingKey {
        case success, type, title, excerpt, domain, cached
        case content_html, cover_image, reading_time_minutes
        case protected, paywalled, confidence, error
        case fetchMethod = "fetch_method"
    }
}

struct ParseError: Codable {
    let code: String
    let message: String
    let fallback: String?
}
