//
//  SyncAction.swift
//  jolt
//
//  Created by Onur Yurdusever on 2.12.2025.
//

import Foundation
import SwiftData

@Model
final class SyncAction {
    @Attribute(.unique) var id: UUID
    var actionType: SyncActionType
    var targetID: UUID  // ID of the bookmark or collection being acted upon
    var timestamp: Date
    var isProcessed: Bool
    
    init(
        id: UUID = UUID(),
        actionType: SyncActionType,
        targetID: UUID,
        timestamp: Date = Date(),
        isProcessed: Bool = false
    ) {
        self.id = id
        self.actionType = actionType
        self.targetID = targetID
        self.timestamp = timestamp
        self.isProcessed = isProcessed
    }
}

enum SyncActionType: String, Codable {
    case delete     // Delete bookmark
    case archive    // Archive bookmark
    case read       // Mark as read
    case unread     // Mark as unread
}
