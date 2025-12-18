//
//  Collection.swift
//  jolt
//
//  Created by Antigravity on 18.12.2025.
//

import Foundation
import SwiftData

@Model
final class JoltCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String?
    var orderIndex: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \Bookmark.collection)
    var bookmarks: [Bookmark]?
    
    init(id: UUID = UUID(), name: String, emoji: String? = nil, orderIndex: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
}
