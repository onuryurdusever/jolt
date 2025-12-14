//
//  ExpirationService.swift
//  jolt
//
//  Created for Jolt v2.1 - Expiration Engine
//

import Foundation
import SwiftData
import UserNotifications

/// Manages the v2.1 Expiration Engine
/// - Auto-archives expired bookmarks (7 days for free, 14 for premium)
/// - Hard deletes archived bookmarks after 30 days
/// - Tracks training mode status
/// - Schedules expiration notifications
@MainActor
class ExpirationService {
    static let shared = ExpirationService()
    
    private init() {}
    
    // MARK: - Training Mode
    
    /// Check if user is in training mode (first 3 days)
    func isInTrainingMode() -> Bool {
        guard let trainingStartDate = UserDefaults.standard.object(forKey: "trainingStartDate") as? Date else {
            return false
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trainingStartDate, to: Date()).day ?? 0
        return daysSinceStart < 3
    }
    
    /// Days remaining in training mode
    func trainingDaysRemaining() -> Int {
        guard let trainingStartDate = UserDefaults.standard.object(forKey: "trainingStartDate") as? Date else {
            return 0
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trainingStartDate, to: Date()).day ?? 0
        return max(0, 3 - daysSinceStart)
    }
    
    /// Start training mode for new users
    func startTrainingMode() {
        if UserDefaults.standard.object(forKey: "trainingStartDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "trainingStartDate")
            print("🛡️ Training mode started")
        }
    }
    
    /// Check if training mode has ended and show alert if needed
    func checkTrainingModeEnded() -> Bool {
        guard let trainingStartDate = UserDefaults.standard.object(forKey: "trainingStartDate") as? Date else {
            return false
        }
        
        let trainingEndShown = UserDefaults.standard.bool(forKey: "trainingEndShown")
        if trainingEndShown { return false }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trainingStartDate, to: Date()).day ?? 0
        if daysSinceStart >= 3 {
            UserDefaults.standard.set(true, forKey: "trainingEndShown")
            return true // Show training ended alert
        }
        return false
    }
    
    // MARK: - Premium Status
    
    /// Check if user has premium subscription
    func isPremium() -> Bool {
        // TODO: Integrate with StoreKit/PremiumService
        return UserDefaults.standard.bool(forKey: "isPremium")
    }
    
    /// Get expiration duration in days (7 for free, 14 for premium)
    func expirationDays() -> Int {
        return isPremium() ? 14 : 7
    }
    
    // MARK: - Expiration Processing
    
    /// Process expired bookmarks - call on app launch and periodically
    func processExpiredBookmarks(modelContext: ModelContext) {
        // Skip if in training mode
        guard !isInTrainingMode() else {
            print("🛡️ Training mode active - skipping expiration check")
            return
        }
        
        let now = Date()
        
        // Fetch active bookmarks that have expired
        let activeStatus = BookmarkStatus.active
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.status == activeStatus
            }
        )
        
        guard let bookmarks = try? modelContext.fetch(descriptor) else { return }
        
        var expiredCount = 0
        for bookmark in bookmarks {
            if let expiresAt = bookmark.expiresAt, expiresAt < now {
                bookmark.archiveExpired()
                expiredCount += 1
                print("📦 Auto-archived: \(bookmark.title)")
            }
        }
        
        if expiredCount > 0 {
            try? modelContext.save()
            print("✅ Processed \(expiredCount) expired bookmarks")
            
            // Update widgets
            WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
        }
    }
    
    /// Hard delete old archived bookmarks (30+ days)
    func processHardDeletes(modelContext: ModelContext) {
        let archivedStatus = BookmarkStatus.archived
        let expiredStatus = BookmarkStatus.expired
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.status == archivedStatus || bookmark.status == expiredStatus
            }
        )
        
        guard let bookmarks = try? modelContext.fetch(descriptor) else { return }
        
        var deletedCount = 0
        for bookmark in bookmarks {
            if bookmark.shouldHardDelete {
                modelContext.delete(bookmark)
                deletedCount += 1
                print("🗑️ Hard deleted: \(bookmark.title)")
            }
        }
        
        if deletedCount > 0 {
            try? modelContext.save()
            print("✅ Hard deleted \(deletedCount) old archived bookmarks")
        }
    }
    
    // MARK: - Dying Soon (Urgent) Bookmarks
    
    /// Get bookmarks expiring within 24 hours
    func getDyingSoonBookmarks(modelContext: ModelContext) -> [Bookmark] {
        let activeStatus = BookmarkStatus.active
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.status == activeStatus
            },
            sortBy: [SortDescriptor(\.expiresAt)]
        )
        
        guard let bookmarks = try? modelContext.fetch(descriptor) else { return [] }
        
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        
        return bookmarks.filter { bookmark in
            guard let expiresAt = bookmark.expiresAt else { return false }
            return expiresAt <= tomorrow && expiresAt > now
        }
    }
    
    /// Get count of bookmarks expiring today
    func getDyingSoonCount(modelContext: ModelContext) -> Int {
        return getDyingSoonBookmarks(modelContext: modelContext).count
    }
    
    // MARK: - Notifications
    
    /// Schedule expiration warning notifications
    func scheduleExpirationNotifications(modelContext: ModelContext) {
        let center = UNUserNotificationCenter.current()
        
        // Remove old expiration notifications
        center.getPendingNotificationRequests { requests in
            let oldIds = requests.filter { $0.identifier.starts(with: "jolt-expire-") }.map { $0.identifier }
            if !oldIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIds)
            }
        }
        
        // Get bookmarks expiring in next 2 days
        let dyingBookmarks = getDyingSoonBookmarks(modelContext: modelContext)
        
        // Schedule notifications for last day
        for bookmark in dyingBookmarks {
            guard let expiresAt = bookmark.expiresAt else { continue }
            
            // Notify 24 hours before expiration
            let notifyDate = Calendar.current.date(byAdding: .hour, value: -24, to: expiresAt)!
            guard notifyDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "notification.lastDay.single.title".localized
            content.body = "notification.lastDay.single.body".localized(with: bookmark.title)
            content.sound = .default
            
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let identifier = "jolt-expire-\(bookmark.id.uuidString)"
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
        
        print("📅 Scheduled \(dyingBookmarks.count) expiration notifications")
    }
    
    /// Send training mode ended notification
    func sendTrainingEndedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "notification.training.ended.title".localized
        content.body = "notification.training.ended.body".localized
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "jolt-training-ended", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Stats
    
    /// Get weekly completion stats
    func getWeeklyStats(modelContext: ModelContext) -> WeeklyStats {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        // Fetch all bookmarks archived/completed this week
        let completedStatus = BookmarkStatus.completed
        let expiredStatus = BookmarkStatus.expired
        let archivedStatus = BookmarkStatus.archived
        
        let descriptor = FetchDescriptor<Bookmark>()
        guard let bookmarks = try? modelContext.fetch(descriptor) else {
            return WeeklyStats(completed: 0, autoArchived: 0, snoozed: 0)
        }
        
        var completed = 0
        var autoArchived = 0
        var snoozed = 0
        
        for bookmark in bookmarks {
            guard let archivedAt = bookmark.archivedAt, archivedAt >= weekStart else { continue }
            
            if bookmark.archivedReason == "completed" {
                completed += 1
            } else if bookmark.archivedReason == "auto" {
                autoArchived += 1
            }
            
            if let snoozeCount = bookmark.snoozeCount, snoozeCount > 0 {
                snoozed += snoozeCount
            }
        }
        
        return WeeklyStats(completed: completed, autoArchived: autoArchived, snoozed: snoozed)
    }
}

/// Weekly statistics for Pulse/Stats view
struct WeeklyStats {
    let completed: Int
    let autoArchived: Int
    let snoozed: Int
    
    var completionRate: Double {
        let total = completed + autoArchived
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
    
    var completionRateFormatted: String {
        return String(format: "%.0f", completionRate)
    }
}
