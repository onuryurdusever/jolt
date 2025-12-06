//
//  AppGroup.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation

enum AppGroup {
    static let identifier = "group.com.jolt.shared"
    
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
