//
//  JoltSharedData.swift
//  JoltWidgets
//
//  Shared data model for widget communication
//

import Foundation

/// Shared data structure for App Group communication between main app and widgets
/// IMPORTANT: Must match WidgetSharedData in WidgetDataService.swift
struct JoltSharedData: Codable {
    let currentStreak: Int
    let todayJolts: Int
    let totalJolts: Int
    let pendingCount: Int
    let nextBookmarkTitle: String?
    let nextBookmarkDomain: String?
    let nextBookmarkReadingTime: Int?
    let nextBookmarkId: String?
    let nextBookmarkCoverImage: String? // URL string (was nextBookmarkCoverURL)
    let nextRoutineName: String?
    let nextRoutineTime: Date?
    let dailyGoal: Int // todayJolts mirrored for backward compatibility
    let dailyGoalTarget: Int // The actual daily goal setting (default 3)
    let weeklyActivity: [Int] // Last 7 days jolt counts [6 days ago...today]
    let longestStreak: Int
    let lastUpdated: Date
    
    static let appGroupID = "group.com.jolt.shared"
    static let dataKey = "widget_data"
    
    /// Load shared data from App Group UserDefaults
    static func load() -> JoltSharedData {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(JoltSharedData.self, from: data) else {
            // Return default values if no data available
            return JoltSharedData(
                currentStreak: 0,
                todayJolts: 0,
                totalJolts: 0,
                pendingCount: 0,
                nextBookmarkTitle: nil,
                nextBookmarkDomain: nil,
                nextBookmarkReadingTime: nil,
                nextBookmarkId: nil,
                nextBookmarkCoverImage: nil,
                nextRoutineName: nil,
                nextRoutineTime: nil,
                dailyGoal: 0,
                dailyGoalTarget: 3,
                weeklyActivity: [0, 0, 0, 0, 0, 0, 0],
                longestStreak: 0,
                lastUpdated: Date()
            )
        }
        return decoded
    }
    
    /// Save shared data to App Group UserDefaults (called from main app)
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let encoded = try? JSONEncoder().encode(self) else { return }
        defaults.set(encoded, forKey: Self.dataKey)
    }
}
