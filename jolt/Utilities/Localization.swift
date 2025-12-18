//
//  Localization.swift
//  jolt
//
//  String localization utilities for multi-language support
//

import Foundation
import SwiftUI

// MARK: - String Extension

extension String {
    /// Returns the localized version of the string
    nonisolated var localized: String {
        LanguageManager.currentBundle.localizedString(forKey: self, value: nil, table: nil)
    }
    
    /// Returns the localized string with format arguments
    nonisolated func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
    
    /// Returns localized string from a specific table
    nonisolated func localized(table: String) -> String {
        LanguageManager.currentBundle.localizedString(forKey: self, value: nil, table: table)
    }
}

// MARK: - LocalizedStringKey Extension

extension LocalizedStringKey {
    /// Create a LocalizedStringKey from a localization key string
    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys for type-safe access
enum L10n {
    
    // MARK: - Common
    enum Common {
        static let done = "common.done"
        static let cancel = "common.cancel"
        static let save = "common.save"
        static let delete = "common.delete"
        static let edit = "common.edit"
        static let close = "common.close"
        static let settings = "common.settings"
        static let loading = "common.loading"
        static let error = "common.error"
        static let success = "common.success"
        static let retry = "common.retry"
        static let share = "common.share"
        static let copy = "common.copy"
        static let archive = "common.archive"
        static let snooze = "common.snooze"
    }
    
    // MARK: - Focus Screen
    enum Focus {
        static let title = "focus.title"
        static let emptyTitle = "focus.empty.title"
        static let emptySubtitle = "focus.empty.subtitle"
        static let later = "focus.later"
        static let laterCount = "focus.later.count"
        static let allCaughtUp = "focus.allCaughtUp"
        static let articlesCount = "focus.articles.count"
        static let totalTime = "focus.totalTime"
        static let filterAll = "focus.filter.all"
        static let filter5min = "focus.filter.5min"
        static let filter15min = "focus.filter.15min"
        static let tapToRead = "focus.tapToRead"
        static let pullForward = "focus.pullForward"
    }
    
    // MARK: - Reader
    enum Reader {
        static let joltIt = "reader.joltIt"
        static let joltCompleted = "reader.joltCompleted"
        static let openInBrowser = "reader.openInBrowser"
        static let copyLink = "reader.copyLink"
        static let shareLink = "reader.shareLink"
        static let readingTime = "reader.readingTime"
        static let scrollProgress = "reader.scrollProgress"
    }
    
    // MARK: - Library
    enum Library {
        static let title = "library.title"
        static let subtitle = "library.subtitle"
        static let searchPlaceholder = "library.search.placeholder"
        static let collections = "library.collections"
        static let quickAccess = "library.quickAccess"
        static let newCollection = "library.newCollection"
        static let allBookmarks = "library.allBookmarks"
        static let emptyTitle = "library.empty.title"
        static let emptySubtitle = "library.empty.subtitle"
    }
    
    // MARK: - Pulse (Stats)
    enum Pulse {
        static let title = "pulse.title"
        static let subtitle = "pulse.subtitle"
        static let dayStreak = "pulse.dayStreak"
        static let currentStreak = "pulse.currentStreak"
        static let longestStreak = "pulse.longestStreak"
        static let totalJolts = "pulse.totalJolts"
        static let thisWeek = "pulse.thisWeek"
        static let today = "pulse.today"
        static let insights = "pulse.insights"
        static let yourStats = "pulse.yourStats"
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let readingGoals = "settings.readingGoals"
        static let storageCache = "settings.storageCache"
        static let imageCache = "settings.imageCache"
        static let articleCache = "settings.articleCache"
        static let clearCache = "settings.clearCache"
        static let dataManagement = "settings.dataManagement"
        static let exportData = "settings.exportData"
        static let exportDescription = "settings.export.description"
        static let routines = "settings.routines"
        static let account = "settings.account"
        static let logout = "settings.logout"
    }
    
    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle = "onboarding.welcome.title"
        static let welcomeSubtitle = "onboarding.welcome.subtitle"
        static let step1Title = "onboarding.step1.title"
        static let step1Subtitle = "onboarding.step1.subtitle"
        static let step2Title = "onboarding.step2.title"
        static let step2Subtitle = "onboarding.step2.subtitle"
        static let step3Title = "onboarding.step3.title"
        static let step3Subtitle = "onboarding.step3.subtitle"
        static let getStarted = "onboarding.getStarted"
        static let next = "onboarding.next"
        static let skip = "onboarding.skip"
    }
    
    // MARK: - Widgets
    enum Widget {
        static let streakTitle = "widget.streak.title"
        static let streakDescription = "widget.streak.description"
        static let focusTitle = "widget.focus.title"
        static let focusDescription = "widget.focus.description"
        static let statsTitle = "widget.stats.title"
        static let statsDescription = "widget.stats.description"
        static let quoteTitle = "widget.quote.title"
        static let quoteDescription = "widget.quote.description"
        static let dayStreak = "widget.dayStreak"
        static let nextUp = "widget.nextUp"
        static let allCaughtUp = "widget.allCaughtUp"
        static let tapToRead = "widget.tapToRead"
        static let weekly = "widget.weekly"
        static let thisWeek = "widget.thisWeek"
        static let total = "widget.total"
        static let streak = "widget.streak"
        static let best = "widget.best"
        static let dailyInspiration = "widget.dailyInspiration"
    }
    
    // MARK: - Share Extension
    enum Share {
        static let saveToJolt = "share.saveToJolt"
        static let schedule = "share.schedule"
        static let collection = "share.collection"
        static let note = "share.note"
        static let morning = "share.morning"
        static let evening = "share.evening"
        static let weekend = "share.weekend"
        static let inbox = "share.inbox"
        static let saved = "share.saved"
        static let saving = "share.saving"
    }
    
    // MARK: - Time
    enum Time {
        static let minute = "time.minute"
        static let minutes = "time.minutes"
        static let hour = "time.hour"
        static let hours = "time.hours"
        static let day = "time.day"
        static let days = "time.days"
        static let week = "time.week"
        static let today = "time.today"
        static let tomorrow = "time.tomorrow"
        static let yesterday = "time.yesterday"
    }
    
    // MARK: - Errors
    enum Error {
        static let networkError = "error.network"
        static let loadingFailed = "error.loadingFailed"
        static let saveFailed = "error.saveFailed"
        static let unknown = "error.unknown"
    }
    
    // MARK: - Alerts
    enum Alert {
        static let clearImageCacheTitle = "alert.clearImageCache.title"
        static let clearImageCacheMessage = "alert.clearImageCache.message"
        static let clearArticleCacheTitle = "alert.clearArticleCache.title"
        static let clearArticleCacheMessage = "alert.clearArticleCache.message"
        static let deleteConfirmTitle = "alert.deleteConfirm.title"
        static let deleteConfirmMessage = "alert.deleteConfirm.message"
        static let logoutTitle = "alert.logout.title"
        static let logoutMessage = "alert.logout.message"
    }
    
    // MARK: - Toast Messages
    enum Toast {
        static let copiedToClipboard = "toast.copiedToClipboard"
        static let bookmarkArchived = "toast.bookmarkArchived"
        static let bookmarkSnoozed = "toast.bookmarkSnoozed"
        static let undo = "toast.undo"
        static let alreadySaved = "toast.alreadySaved"
    }
    
    // MARK: - Siri
    enum Siri {
        static let openFocus = "siri.openFocus"
        static let showNextBookmark = "siri.showNextBookmark"
        static let getStreak = "siri.getStreak"
        static let getTodayStats = "siri.getTodayStats"
        static let getPendingCount = "siri.getPendingCount"
        static let weeklySummary = "siri.weeklySummary"
        static let motivateMe = "siri.motivateMe"
        static let snoozeNext = "siri.snoozeNext"
    }
}

// MARK: - Pluralization Helper

/// Helper for pluralized strings
struct Plurals {
    /// Returns pluralized string for count
    /// Usage: Plurals.articles(count: 5) -> "5 articles"
    static func articles(count: Int) -> String {
        String.localizedStringWithFormat(
            LanguageManager.shared.bundle.localizedString(forKey: "plural.articles", value: nil, table: nil),
            count
        )
    }
    
    static func days(count: Int) -> String {
        String.localizedStringWithFormat(
            LanguageManager.shared.bundle.localizedString(forKey: "plural.days", value: nil, table: nil),
            count
        )
    }
    
    static func minutes(count: Int) -> String {
        String.localizedStringWithFormat(
            LanguageManager.shared.bundle.localizedString(forKey: "plural.minutes", value: nil, table: nil),
            count
        )
    }
    
    static func hours(count: Int) -> String {
        String.localizedStringWithFormat(
            LanguageManager.shared.bundle.localizedString(forKey: "plural.hours", value: nil, table: nil),
            count
        )
    }
    
    static func bookmarks(count: Int) -> String {
        String.localizedStringWithFormat(
            LanguageManager.shared.bundle.localizedString(forKey: "plural.bookmarks", value: nil, table: nil),
            count
        )
    }
}
