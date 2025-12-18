//
//  ConfigManager.swift
//  jolt
//
//  Created by Antigravity on 18.12.2025.
//

import SwiftUI
import Combine

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jolt.shared")
    
    @AppStorage("pro_expire_days", store: UserDefaults(suiteName: "group.com.jolt.shared")) var expireDays: Int = 7
    
    private init() {}
    
    /// Süreyi güncelle (Pro kontrolü UI tarafında yapılacak)
    func updateExpireDays(_ days: Int) {
        let clampedDays = max(7, min(30, days))
        self.expireDays = clampedDays
    }
}
