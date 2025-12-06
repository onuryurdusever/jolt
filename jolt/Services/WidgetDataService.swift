//
//  WidgetDataService.swift
//  jolt
//
//  Service to update widget data through App Group
//

import Foundation
import WidgetKit
import SwiftData

/// Shared data structure matching the widget's JoltSharedData
private struct WidgetSharedData: Codable {
    let currentStreak: Int
    let todayJolts: Int
    let totalJolts: Int
    let pendingCount: Int
    let nextBookmarkTitle: String?
    let nextBookmarkDomain: String?
    let nextBookmarkReadingTime: Int?
    let nextBookmarkId: String?
    let nextBookmarkCoverImage: String? // URL string
    let nextRoutineName: String?
    let nextRoutineTime: Date?
    let dailyGoal: Int
    let dailyGoalTarget: Int
    let weeklyActivity: [Int] // 7 days, index 0 = 6 days ago, index 6 = today
    let longestStreak: Int
    let lastUpdated: Date
}

@MainActor
class WidgetDataService {
    static let shared = WidgetDataService()
    
    private let appGroup = "group.com.jolt.shared"
    private let dataKey = "widget_data"
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }
    
    private init() {}
    
    // MARK: - Update All Widget Data
    
    func updateWidgetData(modelContext: ModelContext) {
        guard let defaults = defaults else { return }
        
        // Fetch bookmarks
        let descriptor = FetchDescriptor<Bookmark>()
        guard let bookmarks = try? modelContext.fetch(descriptor) else { return }
        
        // Calculate stats
        let archivedBookmarks = bookmarks.filter { $0.status == .archived }
        let pendingBookmarks = bookmarks.filter { $0.status == .ready || $0.status == .pending }
            .sorted { $0.scheduledFor < $1.scheduledFor }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Today's jolts
        let todayJolts = archivedBookmarks.filter { bookmark in
            guard let readAt = bookmark.readAt else { return false }
            return calendar.isDate(readAt, inSameDayAs: today)
        }.count
        
        // Weekly activity (last 7 days)
        var weeklyActivity = [Int](repeating: 0, count: 7)
        for dayOffset in 0..<7 {
            let daysAgo = 6 - dayOffset // Index 0 = 6 days ago, Index 6 = today
            guard let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            weeklyActivity[dayOffset] = archivedBookmarks.filter { bookmark in
                guard let readAt = bookmark.readAt else { return false }
                return calendar.isDate(readAt, inSameDayAs: targetDate)
            }.count
        }
        
        // Get streak and settings from UserDefaults
        let currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        let longestStreak = UserDefaults.standard.integer(forKey: "longestStreak")
        let dailyGoalTarget = max(1, UserDefaults.standard.integer(forKey: "dailyGoalTarget"))
        
        // Next bookmark info
        let nextBookmark = pendingBookmarks.first
        
        // Next routine info
        let (nextRoutineName, nextRoutineTime) = getNextRoutineInfo()
        
        // Create shared data object
        let sharedData = WidgetSharedData(
            currentStreak: currentStreak,
            todayJolts: todayJolts,
            totalJolts: archivedBookmarks.count,
            pendingCount: pendingBookmarks.count,
            nextBookmarkTitle: nextBookmark?.title,
            nextBookmarkDomain: nextBookmark?.domain,
            nextBookmarkReadingTime: nextBookmark?.readingTimeMinutes,
            nextBookmarkId: nextBookmark?.id.uuidString,
            nextBookmarkCoverImage: nextBookmark?.coverImage,
            nextRoutineName: nextRoutineName,
            nextRoutineTime: nextRoutineTime,
            dailyGoal: todayJolts,
            dailyGoalTarget: dailyGoalTarget == 0 ? 3 : dailyGoalTarget, // Default 3
            weeklyActivity: weeklyActivity,
            longestStreak: max(longestStreak, currentStreak),
            lastUpdated: Date()
        )
        
        // Save as JSON
        if let encoded = try? JSONEncoder().encode(sharedData) {
            defaults.set(encoded, forKey: dataKey)
        }
        
        // Refresh widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Quick Updates
    
    func updateStreak(_ streak: Int) {
        updateCurrentData { data in
            WidgetSharedData(
                currentStreak: streak,
                todayJolts: data.todayJolts,
                totalJolts: data.totalJolts,
                pendingCount: data.pendingCount,
                nextBookmarkTitle: data.nextBookmarkTitle,
                nextBookmarkDomain: data.nextBookmarkDomain,
                nextBookmarkReadingTime: data.nextBookmarkReadingTime,
                nextBookmarkId: data.nextBookmarkId,
                nextBookmarkCoverImage: data.nextBookmarkCoverImage,
                nextRoutineName: data.nextRoutineName,
                nextRoutineTime: data.nextRoutineTime,
                dailyGoal: data.dailyGoal,
                dailyGoalTarget: data.dailyGoalTarget,
                weeklyActivity: data.weeklyActivity,
                longestStreak: max(data.longestStreak, streak),
                lastUpdated: Date()
            )
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
    }
    
    func incrementTodayJolts() {
        updateCurrentData { data in
            var updatedWeekly = data.weeklyActivity
            if updatedWeekly.count == 7 {
                updatedWeekly[6] += 1 // Today is last index
            }
            
            return WidgetSharedData(
                currentStreak: data.currentStreak,
                todayJolts: data.todayJolts + 1,
                totalJolts: data.totalJolts + 1,
                pendingCount: max(0, data.pendingCount - 1),
                nextBookmarkTitle: nil,
                nextBookmarkDomain: nil,
                nextBookmarkReadingTime: nil,
                nextBookmarkId: nil,
                nextBookmarkCoverImage: nil,
                nextRoutineName: data.nextRoutineName,
                nextRoutineTime: data.nextRoutineTime,
                dailyGoal: data.dailyGoal + 1,
                dailyGoalTarget: data.dailyGoalTarget,
                weeklyActivity: updatedWeekly,
                longestStreak: data.longestStreak,
                lastUpdated: Date()
            )
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func clearNextBookmark() {
        updateCurrentData { data in
            WidgetSharedData(
                currentStreak: data.currentStreak,
                todayJolts: data.todayJolts,
                totalJolts: data.totalJolts,
                pendingCount: max(0, data.pendingCount - 1),
                nextBookmarkTitle: nil,
                nextBookmarkDomain: nil,
                nextBookmarkReadingTime: nil,
                nextBookmarkId: nil,
                nextBookmarkCoverImage: nil,
                nextRoutineName: data.nextRoutineName,
                nextRoutineTime: data.nextRoutineTime,
                dailyGoal: data.dailyGoal,
                dailyGoalTarget: data.dailyGoalTarget,
                weeklyActivity: data.weeklyActivity,
                longestStreak: data.longestStreak,
                lastUpdated: Date()
            )
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }
    
    // MARK: - Private Helpers
    
    private func getNextRoutineInfo() -> (String?, Date?) {
        // Routine bilgilerini UserDefaults'tan al
        guard let routinesData = UserDefaults.standard.data(forKey: "routines"),
              let routines = try? JSONDecoder().decode([RoutineInfo].self, from: routinesData) else {
            return (nil, nil)
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Find next scheduled routine
        for routine in routines where routine.isEnabled {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = routine.hour
            components.minute = routine.minute
            
            if let routineTime = calendar.date(from: components) {
                if routineTime > now {
                    return (routine.name, routineTime)
                }
            }
        }
        
        return (nil, nil)
    }
    
    private func loadCurrentData() -> WidgetSharedData {
        guard let defaults = defaults,
              let jsonData = defaults.data(forKey: dataKey),
              let data = try? JSONDecoder().decode(WidgetSharedData.self, from: jsonData) else {
            return WidgetSharedData(
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
        return data
    }
    
    private func updateCurrentData(_ transform: (WidgetSharedData) -> WidgetSharedData) {
        let current = loadCurrentData()
        let updated = transform(current)
        
        if let defaults = defaults,
           let encoded = try? JSONEncoder().encode(updated) {
            defaults.set(encoded, forKey: dataKey)
        }
    }
}

// MARK: - Routine Info for Decoding

private struct RoutineInfo: Codable {
    let name: String
    let hour: Int
    let minute: Int
    let isEnabled: Bool
}
