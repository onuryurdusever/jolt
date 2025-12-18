//
//  JoltAppIntents.swift
//  jolt
//
//  App Intents for Siri Shortcuts
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - Open Focus Intent

struct OpenFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.openFocus.title"
    static let description = IntentDescription("siri.openFocus.description")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Show Next Bookmark Intent

struct ShowNextBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.showNextBookmark.title"
    static let description = IntentDescription("siri.showNextBookmark.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: IntentDialog(stringLiteral: "siri.showNextBookmark.empty".localized))
        }
        
        if let title = decoded.nextBookmarkTitle,
           let domain = decoded.nextBookmarkDomain,
           let time = decoded.nextBookmarkReadingTime {
            return .result(dialog: IntentDialog(stringLiteral: "siri.showNextBookmark.success".localized(with: title, domain, time)))
        } else {
            return .result(dialog: IntentDialog(stringLiteral: "siri.showNextBookmark.allCaughtUp".localized))
        }
    }
}

// MARK: - Get Streak Intent

struct GetStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.getStreak.title"
    static let description = IntentDescription("siri.getStreak.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        
        let dialogString: String
        switch streak {
        case 0:
            dialogString = "siri.getStreak.zero".localized
        case 1:
            dialogString = "siri.getStreak.one".localized
        case 2...6:
            dialogString = "siri.getStreak.multiple".localized(with: streak)
        case 7...13:
            dialogString = "siri.getStreak.week".localized(with: streak)
        case 14...29:
            dialogString = "siri.getStreak.twoWeeks".localized(with: streak)
        default:
            dialogString = "siri.getStreak.legend".localized(with: streak)
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialogString))
    }
}

// MARK: - Get Today Stats Intent

struct GetTodayStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.getTodayStats.title"
    static let description = IntentDescription("siri.getTodayStats.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: IntentDialog(stringLiteral: "siri.getTodayStats.empty".localized))
        }
        
        let todayJolts = decoded.todayJolts
        let totalJolts = decoded.totalJolts
        
        let dialogString: String
        switch todayJolts {
        case 0:
            dialogString = "siri.getTodayStats.empty".localized
        case 1:
            dialogString = "siri.getTodayStats.one".localized(with: totalJolts)
        case 2...4:
            dialogString = "siri.getTodayStats.multiple".localized(with: todayJolts, totalJolts)
        default:
            dialogString = "siri.getTodayStats.legend".localized(with: todayJolts, totalJolts)
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialogString))
    }
}

// MARK: - Get Pending Count Intent

struct GetPendingCountIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.getPendingCount.title"
    static let description = IntentDescription("siri.getPendingCount.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: IntentDialog(stringLiteral: "siri.getPendingCount.empty".localized))
        }
        
        let pending = decoded.pendingCount
        
        let dialogString: String
        switch pending {
        case 0:
            dialogString = "siri.getPendingCount.empty".localized
        case 1:
            dialogString = "siri.getPendingCount.one".localized
        case 2...5:
            dialogString = "siri.getPendingCount.few".localized(with: pending)
        case 6...10:
            dialogString = "siri.getPendingCount.many".localized(with: pending)
        default:
            dialogString = "siri.getPendingCount.veryMany".localized(with: pending)
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialogString))
    }
}

// MARK: - Weekly Summary Intent

struct WeeklySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.weeklySummary.title"
    static let description = IntentDescription("siri.weeklySummary.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: IntentDialog(stringLiteral: "siri.weeklySummary.noData".localized))
        }
        
        let total = decoded.totalJolts
        let pending = decoded.pendingCount
        
        let dialogString = "siri.weeklySummary.dialog".localized(with: streak, total, pending)
        
        return .result(dialog: IntentDialog(stringLiteral: dialogString))
    }
}

// MARK: - Motivational Quote Intent

struct MotivationIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.motivation.title"
    static let description = IntentDescription("siri.motivation.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Use localized quotes from Localizable.strings
        let totalQuotes = 30
        let randomIndex = Int.random(in: 1...totalQuotes)
        let dialogString = "quote.\(randomIndex)".localized
        
        return .result(dialog: IntentDialog(stringLiteral: dialogString))
    }
}

// MARK: - Widget Data Model for Decoding

private struct WidgetData: Codable {
    let currentStreak: Int
    let todayJolts: Int
    let totalJolts: Int
    let pendingCount: Int
    let nextBookmarkTitle: String?
    let nextBookmarkDomain: String?
    let nextBookmarkReadingTime: Int?
    let nextBookmarkId: String? // UUID string for snooze action
    let lastUpdated: Date
}

// MARK: - Snooze Next Bookmark Intent

struct SnoozeNextBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "siri.snoozeNext.title"
    static let description = IntentDescription("siri.snoozeNext.description")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Save snooze request to UserDefaults - app will handle it when opened
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        defaults?.set(true, forKey: "siri_snooze_request")
        defaults?.set(Date(), forKey: "siri_snooze_request_time")
        
        // Get bookmark title for confirmation
        if let data = defaults?.data(forKey: "widget_data"),
           let decoded = try? JSONDecoder().decode(WidgetData.self, from: data),
           let title = decoded.nextBookmarkTitle {
            return .result(dialog: IntentDialog(stringLiteral: "siri.snoozeNext.success".localized(with: title)))
        }
        
        return .result(dialog: IntentDialog(stringLiteral: "siri.snoozeNext.notFound".localized))
    }
}

// MARK: - Shortcuts Provider

struct JoltShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Aç
        AppShortcut(
            intent: OpenFocusIntent(),
            phrases: [
                "\(.applicationName) open",
                "\(.applicationName) start"
            ],
            shortTitle: "common.open",
            systemImageName: "bolt.fill"
        )
        
        // Sonraki içerik
        AppShortcut(
            intent: ShowNextBookmarkIntent(),
            phrases: [
                "\(.applicationName) next",
                "\(.applicationName) show next"
            ],
            shortTitle: "focus.later",
            systemImageName: "book.fill"
        )
        
        // Streak
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "\(.applicationName) streak",
                "\(.applicationName) my streak"
            ],
            shortTitle: "pulse.dayStreak",
            systemImageName: "flame.fill"
        )
        
        // Bugün
        AppShortcut(
            intent: GetTodayStatsIntent(),
            phrases: [
                "\(.applicationName) today",
                "\(.applicationName) daily"
            ],
            shortTitle: "pulse.today",
            systemImageName: "sun.max.fill"
        )
        
        // Bekleyenler
        AppShortcut(
            intent: GetPendingCountIntent(),
            phrases: [
                "\(.applicationName) pending",
                "\(.applicationName) inbox"
            ],
            shortTitle: "focus.title",
            systemImageName: "tray.full.fill"
        )
        
        // Haftalık özet
        AppShortcut(
            intent: WeeklySummaryIntent(),
            phrases: [
                "\(.applicationName) weekly",
                "\(.applicationName) report"
            ],
            shortTitle: "pulse.thisWeek",
            systemImageName: "calendar"
        )
        
        // Motivasyon
        AppShortcut(
            intent: MotivationIntent(),
            phrases: [
                "\(.applicationName) motivate",
                "\(.applicationName) inspire"
            ],
            shortTitle: "pulse.settings.support",
            systemImageName: "sparkles"
        )
        
        // Ertele
        AppShortcut(
            intent: SnoozeNextBookmarkIntent(),
            phrases: [
                "\(.applicationName) snooze",
                "\(.applicationName) not now"
            ],
            shortTitle: "snooze.action",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
