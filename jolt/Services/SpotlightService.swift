//
//  SpotlightService.swift
//  jolt
//
//  CoreSpotlight integration for bookmark indexing
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import SwiftData

@MainActor
class SpotlightService {
    static let shared = SpotlightService()
    
    private let searchableIndex = CSSearchableIndex.default()
    private let domainIdentifier = "com.jolt.bookmarks"
    
    private init() {}
    
    // MARK: - Index Single Bookmark
    
    func indexBookmark(_ bookmark: Bookmark) {
        let attributeSet = createAttributeSet(for: bookmark)
        
        let item = CSSearchableItem(
            uniqueIdentifier: bookmark.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        // Items expire after 30 days if not updated
        item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
        
        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("❌ Spotlight index error: \(error.localizedDescription)")
            } else {
                print("✅ Indexed: \(bookmark.title)")
            }
        }
    }
    
    // MARK: - Index All Bookmarks
    
    func indexAllBookmarks(from context: ModelContext) {
        let descriptor = FetchDescriptor<Bookmark>()
        guard let bookmarks = try? context.fetch(descriptor) else { return }
        
        let items = bookmarks.map { bookmark -> CSSearchableItem in
            let attributeSet = createAttributeSet(for: bookmark)
            let item = CSSearchableItem(
                uniqueIdentifier: bookmark.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
            return item
        }
        
        searchableIndex.indexSearchableItems(items) { error in
            if let error = error {
                print("❌ Spotlight batch index error: \(error.localizedDescription)")
            } else {
                print("✅ Indexed \(items.count) bookmarks")
            }
        }
    }
    
    // MARK: - Remove Bookmark from Index
    
    func removeBookmark(_ bookmark: Bookmark) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [bookmark.id.uuidString]) { error in
            if let error = error {
                print("❌ Spotlight remove error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Remove All
    
    func removeAllBookmarks() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                print("❌ Spotlight clear error: \(error.localizedDescription)")
            } else {
                print("✅ Cleared all Spotlight items")
            }
        }
    }
    
    // MARK: - Create Attribute Set
    
    private func createAttributeSet(for bookmark: Bookmark) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
        
        // Basic info
        attributeSet.title = bookmark.title
        attributeSet.contentDescription = bookmark.excerpt ?? bookmark.contentHTML?.prefix(200).description
        attributeSet.url = URL(string: bookmark.originalURL)
        
        // Domain as author
        attributeSet.creator = bookmark.domain
        
        // Keywords for better search
        var keywords = [bookmark.domain, bookmark.type.rawValue]
        if let collection = bookmark.collection {
            keywords.append(collection.name)
        }
        attributeSet.keywords = keywords
        
        // Reading time
        attributeSet.duration = NSNumber(value: bookmark.readingTimeMinutes * 60)
        
        // Thumbnail
        if let coverURL = bookmark.coverImage, let url = URL(string: coverURL) {
            attributeSet.thumbnailURL = url
        }
        
        // Content type based on bookmark type
        switch bookmark.type {
        case .video:
            attributeSet.contentType = UTType.movie.identifier
        case .audio:
            attributeSet.contentType = UTType.audio.identifier
        case .pdf:
            attributeSet.contentType = UTType.pdf.identifier
        default:
            attributeSet.contentType = UTType.url.identifier
        }
        
        // Display name with reading time
        attributeSet.displayName = "\(bookmark.title) (\(bookmark.readingTimeMinutes) dk)"
        
        // Status indicator
        if bookmark.status == .archived {
            attributeSet.addedDate = bookmark.readAt
        } else {
            attributeSet.addedDate = bookmark.createdAt
        }
        
        return attributeSet
    }
    
    // MARK: - Handle Spotlight Selection
    
    static func bookmarkID(from userActivity: NSUserActivity) -> UUID? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: uniqueIdentifier) else {
            return nil
        }
        return uuid
    }
}
