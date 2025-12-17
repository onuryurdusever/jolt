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
class EnrichmentService: ObservableObject {
    static let shared = EnrichmentService()
    
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
    
    func processPendingEnrichments(context: ModelContext) async {
        guard !isSyncing else {
            print("⚠️ Enrichment skipped: Already in progress (Single-flight protection)")
            return
        }
        
        // Check network first
        guard networkMonitor.isOnline else {
            print("⚠️ Enrichment skipped: Offline")
            return
        }
        
        isSyncing = true
        syncProgress = "Processing queue..."
        defer { 
            isSyncing = false
            syncProgress = ""
        }
        
        do {
            // Predicate-based fetch: Only get what needs work

            let now = Date()
            let past = Date.distantPast
            
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate<Bookmark> { bookmark in
                    bookmark.needsEnrichment &&
                    (bookmark.enrichmentNextAttemptAt ?? past) <= now
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)] // Process oldest first (FIFO)
            )
            // Limit batch size to prevent memory bloat
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = 10
            
            let batch = try context.fetch(fetchDescriptor)
            
            guard !batch.isEmpty else {
                print("✅ Enrichment Queue Empty: Nothing to process")
                return
            }
            
            print("🔄 Enrichment Batch Started: Processing \(batch.count) items...")
            
            await withTaskGroup(of: (Bookmark, ParsedContent?).self) { group in
                for bookmark in batch {
                    // Mark in-progress
                    bookmark.enrichmentStatus = .inProgress
                    
                    group.addTask {
                        let parsed = await self.parseURL(bookmark.originalURL)
                        return (bookmark, parsed)
                    }
                }
                
                for await (bookmark, parsed) in group {
                    if let result = parsed, result.success != false {
                        // Success path
                        updateBookmark(bookmark, with: result, context: context)
                        bookmark.needsEnrichment = false
                        bookmark.enrichmentStatus = .done
                        bookmark.enrichmentAttempts = 0
                        bookmark.enrichmentNextAttemptAt = nil
                        print("✅ Enriched: \(bookmark.title)")
                    } else {
                        // Failure path with Exponential Backoff
                        bookmark.enrichmentAttempts += 1
                        bookmark.enrichmentStatus = bookmark.enrichmentAttempts >= 5 ? .failed : .pending
                        
                        // Backoff: 1m, 10m, 1h, 6h, 24h
                        let delayMinutes: Int
                        switch bookmark.enrichmentAttempts {
                        case 1: delayMinutes = 1
                        case 2: delayMinutes = 10
                        case 3: delayMinutes = 60
                        case 4: delayMinutes = 360
                        default: delayMinutes = 1440
                        }
                        
                        bookmark.enrichmentNextAttemptAt = Calendar.current.date(byAdding: .minute, value: delayMinutes, to: Date())
                        print("⚠️ Enrichment Failed for \(bookmark.originalURL). Retry #\(bookmark.enrichmentAttempts) in \(delayMinutes)m.")
                    }
                }
            }
            
            try context.save()
            print("✅ Enrichment Batch Complete")
            
        } catch {
            print("❌ Enrichment Fatal Error: \(error)")
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
                "user_id": AuthService.shared.currentUserID ?? "",
                "skip_cache": true // DEBUG: Force fresh parse to fix 0 min issue
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [Parser] Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            // Log raw response for debugging
            if let rawString = String(data: data, encoding: .utf8) {
                print("📥 [Parser] Raw Response (\(httpResponse.statusCode)): \(rawString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [Parser] Server error status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            do {
                let parsed = try JSONDecoder().decode(ParsedContent.self, from: data)
                return parsed
            } catch let decodingError as DecodingError {
                print("❌ [Parser] Decoding Error for \(url): \(decodingError)")
                // Print specific decoding context
                switch decodingError {
                case .typeMismatch(let key, let value):
                    print("   Type mismatch for key: \(key), value: \(value)")
                case .valueNotFound(let key, let value):
                    print("   Value not found for key: \(key), value: \(value)")
                case .keyNotFound(let key, let value):
                    print("   Key not found: \(key), context: \(value)")
                case .dataCorrupted(let key):
                    print("   Data corrupted: \(key)")
                @unknown default:
                    print("   Unknown decoding error")
                }
                return nil
            } catch {
                print("❌ [Parser] General Error: \(error)")
                return nil
            }
            
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
        
        // If parsing totally failed, return early so we can see the error in logs
        // Do NOT generate mock data as requested
        guard let parsed = parsed else {
            print("⚠️ [Parser] Parsing returned nil for \(bookmark.originalURL). Skipping update.")
            return
        }

        if isSocialMedia {
            if let title = parsed.title, !title.isEmpty {
                bookmark.title = title
            } else {
                 bookmark.title = extractSocialMediaTitle(from: bookmark.originalURL, domain: domain)
            }
            
            bookmark.excerpt = parsed.excerpt
            bookmark.coverImage = parsed.cover_image
            // Use parsed reading time if valid, otherwise fallback to 2 for social
            let minutes = parsed.reading_time_minutes ?? 0
            bookmark.readingTimeMinutes = minutes > 0 ? minutes : 2
            
            // v3.0 fields
            bookmark.isProtected = parsed.protected
            bookmark.isPaywalled = parsed.paywalled
            bookmark.fetchMethod = parsed.fetchMethod
            bookmark.parseConfidence = parsed.confidence
            bookmark.webviewReason = parsed.webviewReason
            
            bookmark.type = .social
            bookmark.contentHTML = nil // Force webview
        } else {
            // Normal article/website parsing
            let title = parsed.title ?? ""
            bookmark.title = title.isEmpty ? EnrichmentService.shared.extractTitleFromURL(bookmark.originalURL) : title
            bookmark.excerpt = parsed.excerpt
            bookmark.contentHTML = parsed.content_html
            bookmark.coverImage = parsed.cover_image
            bookmark.readingTimeMinutes = parsed.reading_time_minutes ?? 0
            
            // v3.0 fields
            bookmark.isProtected = parsed.protected
            bookmark.isPaywalled = parsed.paywalled
            bookmark.fetchMethod = parsed.fetchMethod
            bookmark.parseConfidence = parsed.confidence
            bookmark.webviewReason = parsed.webviewReason
            
            // Determine type based on parsed response
            let typeString = parsed.type ?? "webview"
            let parsedType = BookmarkType(rawValue: typeString) ?? .webview
            
            // Force webview for protected/paywalled or low confidence content
            if parsed.protected == true || parsed.paywalled == true {
                bookmark.type = parsedType == .video ? .video : .webview
            } else if let confidence = parsed.confidence, confidence < 0.3 {
                bookmark.type = .webview
            } else if let contentHTML = parsed.content_html, contentHTML.count < 500 {
                // Content too short - likely truncated, force webview for complete display
                bookmark.type = .webview
                bookmark.contentHTML = nil // Don't show truncated content
                print("⚠️ Content too short (\(contentHTML.count) chars), forcing webview for \(bookmark.domain ?? "unknown")")
            } else {
                bookmark.type = parsedType
            }
        }
        
        bookmark.domain = URL(string: bookmark.originalURL)?.host ?? domain
        // v2.1: Keep as active (no more pending->ready transition)
        bookmark.status = .active
        
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
    let type: String?
    let title: String?
    let excerpt: String?
    let content_html: String?
    let cover_image: String?
    let reading_time_minutes: Int?
    let domain: String?
    let cached: Bool?
    // v3.0 fields
    let protected: Bool?       // Content requires authentication
    let paywalled: Bool?       // Content is behind paywall
    let fetchMethod: String?   // 'api', 'oembed', 'readability', 'meta-only', 'webview'
    let confidence: Double?    // 0.0-1.0 parse quality score
    let error: ParseError?     // Error details if parsing failed
    let webviewReason: String? // Reason for falling back to webview
    
    enum CodingKeys: String, CodingKey {
        case success, type, title, excerpt, domain, cached
        case content_html, cover_image, reading_time_minutes
        case protected, paywalled, confidence, error, webviewReason
        case fetchMethod = "fetch_method"
    }
}

struct ParseError: Codable {
    let code: String
    let message: String
    let fallback: String?
}
