//
//  Achievement.swift
//  jolt
//
//  Created by Onur Yurdusever on 4.12.2025.
//

import Foundation
import SwiftUI

enum Achievement: String, CaseIterable, Identifiable {
    case firstJolt = "first_jolt"
    case fiveJolts = "five_jolts"
    case twentyFiveJolts = "twentyfive_jolts"
    case fiftyJolts = "fifty_jolts"
    case centurion = "centurion"
    case weekStreak = "week_streak"
    case twoWeekStreak = "two_week_streak"
    case monthStreak = "month_streak"
    case speedReader = "speed_reader"
    case nightOwl = "night_owl"
    case earlyBird = "early_bird"
    case curator = "curator"
    case socialButterfly = "social_butterfly"
    case bookworm = "bookworm"
    
    var id: String { rawValue }
    
    var title: String {
        "achievement.\(rawValue).title".localized
    }
    
    var description: String {
        "achievement.\(rawValue).description".localized
    }
    
    var icon: String {
        switch self {
        case .firstJolt: return "bolt.fill"
        case .fiveJolts: return "star.fill"
        case .twentyFiveJolts: return "star.circle.fill"
        case .fiftyJolts: return "medal.fill"
        case .centurion: return "crown.fill"
        case .weekStreak: return "flame.fill"
        case .twoWeekStreak: return "flame.circle.fill"
        case .monthStreak: return "trophy.fill"
        case .speedReader: return "hare.fill"
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        case .curator: return "folder.fill.badge.plus"
        case .socialButterfly: return "bubble.left.and.bubble.right.fill"
        case .bookworm: return "book.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstJolt: return .joltYellow
        case .fiveJolts: return .orange
        case .twentyFiveJolts: return .purple
        case .fiftyJolts: return .blue
        case .centurion: return .yellow
        case .weekStreak: return Color(red: 1, green: 0.38, blue: 0.2)
        case .twoWeekStreak: return Color(red: 1, green: 0.5, blue: 0.3)
        case .monthStreak: return Color(red: 1, green: 0.84, blue: 0)
        case .speedReader: return .green
        case .nightOwl: return .indigo
        case .earlyBird: return .orange
        case .curator: return .teal
        case .socialButterfly: return .pink
        case .bookworm: return .brown
        }
    }
    
    var targetValue: Int {
        switch self {
        case .firstJolt: return 1
        case .fiveJolts: return 5
        case .twentyFiveJolts: return 25
        case .fiftyJolts: return 50
        case .centurion: return 100
        case .weekStreak: return 7
        case .twoWeekStreak: return 14
        case .monthStreak: return 30
        case .speedReader: return 5
        case .nightOwl: return 1
        case .earlyBird: return 1
        case .curator: return 5
        case .socialButterfly: return 10
        case .bookworm: return 30
        }
    }
}

// MARK: - Achievement Manager
class AchievementManager {
    static let shared = AchievementManager()
    private let defaults = UserDefaults.standard
    private let unlockedKey = "unlockedAchievements"
    
    private init() {}
    
    var unlockedAchievements: Set<String> {
        get {
            Set(defaults.stringArray(forKey: unlockedKey) ?? [])
        }
        set {
            defaults.set(Array(newValue), forKey: unlockedKey)
        }
    }
    
    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievements.contains(achievement.rawValue)
    }
    
    func unlock(_ achievement: Achievement) {
        var current = unlockedAchievements
        current.insert(achievement.rawValue)
        unlockedAchievements = current
    }
    
    func checkAndUnlockAchievements(
        totalJolts: Int,
        currentStreak: Int,
        longestStreak: Int,
        collectionsCount: Int,
        socialJolts: Int,
        articleJolts: Int,
        todayJolts: Int,
        lastJoltHour: Int?
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        
        // Jolt count achievements
        if totalJolts >= 1 && !isUnlocked(.firstJolt) {
            unlock(.firstJolt)
            newlyUnlocked.append(.firstJolt)
        }
        if totalJolts >= 5 && !isUnlocked(.fiveJolts) {
            unlock(.fiveJolts)
            newlyUnlocked.append(.fiveJolts)
        }
        if totalJolts >= 25 && !isUnlocked(.twentyFiveJolts) {
            unlock(.twentyFiveJolts)
            newlyUnlocked.append(.twentyFiveJolts)
        }
        if totalJolts >= 50 && !isUnlocked(.fiftyJolts) {
            unlock(.fiftyJolts)
            newlyUnlocked.append(.fiftyJolts)
        }
        if totalJolts >= 100 && !isUnlocked(.centurion) {
            unlock(.centurion)
            newlyUnlocked.append(.centurion)
        }
        
        // Streak achievements
        let maxStreak = max(currentStreak, longestStreak)
        if maxStreak >= 7 && !isUnlocked(.weekStreak) {
            unlock(.weekStreak)
            newlyUnlocked.append(.weekStreak)
        }
        if maxStreak >= 14 && !isUnlocked(.twoWeekStreak) {
            unlock(.twoWeekStreak)
            newlyUnlocked.append(.twoWeekStreak)
        }
        if maxStreak >= 30 && !isUnlocked(.monthStreak) {
            unlock(.monthStreak)
            newlyUnlocked.append(.monthStreak)
        }
        
        // Speed reader
        if todayJolts >= 5 && !isUnlocked(.speedReader) {
            unlock(.speedReader)
            newlyUnlocked.append(.speedReader)
        }
        
        // Time-based achievements
        if let hour = lastJoltHour {
            if hour >= 22 || hour < 4 {
                if !isUnlocked(.nightOwl) {
                    unlock(.nightOwl)
                    newlyUnlocked.append(.nightOwl)
                }
            }
            if hour >= 4 && hour < 7 {
                if !isUnlocked(.earlyBird) {
                    unlock(.earlyBird)
                    newlyUnlocked.append(.earlyBird)
                }
            }
        }
        
        // Curator
        if collectionsCount >= 5 && !isUnlocked(.curator) {
            unlock(.curator)
            newlyUnlocked.append(.curator)
        }
        
        // Social butterfly
        if socialJolts >= 10 && !isUnlocked(.socialButterfly) {
            unlock(.socialButterfly)
            newlyUnlocked.append(.socialButterfly)
        }
        
        // Bookworm
        if articleJolts >= 30 && !isUnlocked(.bookworm) {
            unlock(.bookworm)
            newlyUnlocked.append(.bookworm)
        }
        
        return newlyUnlocked
    }
    
    func getProgress(for achievement: Achievement,
                     totalJolts: Int,
                     currentStreak: Int,
                     longestStreak: Int,
                     collectionsCount: Int,
                     socialJolts: Int,
                     articleJolts: Int,
                     todayJolts: Int) -> Double {
        let current: Int
        let target = achievement.targetValue
        
        switch achievement {
        case .firstJolt, .fiveJolts, .twentyFiveJolts, .fiftyJolts, .centurion:
            current = totalJolts
        case .weekStreak, .twoWeekStreak, .monthStreak:
            current = max(currentStreak, longestStreak)
        case .speedReader:
            current = todayJolts
        case .nightOwl, .earlyBird:
            current = isUnlocked(achievement) ? 1 : 0
        case .curator:
            current = collectionsCount
        case .socialButterfly:
            current = socialJolts
        case .bookworm:
            current = articleJolts
        }
        
        return min(Double(current) / Double(target), 1.0)
    }
}
