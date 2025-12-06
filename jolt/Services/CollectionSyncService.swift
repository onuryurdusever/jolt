//
//  CollectionSyncService.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation
import SwiftData

class CollectionSyncService {
    static let shared = CollectionSyncService()
    
    private init() {}
    
    func syncCollectionsToAppGroup(collections: [Collection]) {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jolt.shared") else {
            print("❌ Failed to get App Group container")
            return
        }
        
        let sharedCollections = collections.map { collection in
            SharedCollectionData(
                id: collection.id,
                name: collection.name,
                color: collection.color,
                icon: collection.icon
            )
        }
        
        do {
            let data = try JSONEncoder().encode(sharedCollections)
            let fileURL = appGroupURL.appendingPathComponent("collections.json")
            try data.write(to: fileURL)
            print("✅ Synced \(collections.count) collections to App Group")
        } catch {
            print("❌ Failed to sync collections: \(error)")
        }
    }
}

struct SharedCollectionData: Codable {
    let id: UUID
    let name: String
    let color: String
    let icon: String
}
