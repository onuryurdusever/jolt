//
//  Collection.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation
import SwiftData

@Model
final class Collection {
    @Attribute(.unique) var id: UUID
    var userID: String
    var name: String
    var color: String // Hex color
    var icon: String // SF Symbol name
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \Bookmark.collection)
    var bookmarks: [Bookmark] = []
    
    init(
        id: UUID = UUID(),
        userID: String,
        name: String,
        color: String = "#CCFF00",
        icon: String = "folder.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }
}
