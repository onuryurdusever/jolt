//
//  NotificationManager.swift
//  jolt
//
//  v3.0 - Modern Swift Concurrency ile yeniden yazıldı
//

import UserNotifications
import SwiftData
import UIKit

/// Thread-safe bildirim yöneticisi
/// Actor kullanarak race condition'ları önler
actor NotificationScheduler {
    static let shared = NotificationScheduler()
    
    private var currentTask: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Ana bildirim zamanlama fonksiyonu
    /// Çoklu çağrılarda sadece son çağrı işlenir (debounce)
    func scheduleNotifications(routines: [Routine], bookmarks: [Bookmark]) async {
        // Mevcut task'ı iptal et (debounce)
        if currentTask != nil {
            #if DEBUG
            print("⏸️ Cancelling previous scheduling task (debounce)")
            #endif
            currentTask?.cancel()
        }
        
        let newTask = Task {
            // Daha uzun debounce süresi - uygulama açılışında çoklu tetikleme olabiliyor
            try? await Task.sleep(for: .milliseconds(1000))
            
            guard !Task.isCancelled else {
                #if DEBUG
                print("⏭️ Notification scheduling cancelled (debounced)")
                #endif
                return
            }
            
            await performScheduling(routines: routines, bookmarks: bookmarks)
        }
        
        currentTask = newTask
        
        // Task'ın tamamlanmasını bekle ama iptal edilirse devam et
        _ = await newTask.result
    }
    
    /// İzin durumunu kontrol et
    func checkPermission() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// İzin iste
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                #if DEBUG
                print("✅ Notification permission granted")
                #endif
                await MainActor.run {
                    UserDefaults(suiteName: "group.com.jolt.shared")?.set(true, forKey: "notificationPermissionGranted")
                }
            } else {
                #if DEBUG
                print("❌ Notification permission denied")
                #endif
            }
            return granted
        } catch {
            #if DEBUG
            print("❌ Notification permission error: \(error.localizedDescription)")
            #endif
            return false
        }
    }
    
    /// Tüm bildirimleri iptal et
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        #if DEBUG
        print("🗑️ All notifications cancelled")
        #endif
    }
    
    // MARK: - Private Implementation
    
    private func performScheduling(routines: [Routine], bookmarks: [Bookmark]) async {
        #if DEBUG
        print("🔔 Starting notification scheduling...")
        #endif
        
        // 1. İzin kontrolü
        let status = await checkPermission()
        guard status == .authorized else {
            #if DEBUG
            print("⚠️ Notifications not authorized (status: \(status.rawValue))")
            #endif
            return
        }
        
        // 2. Mevcut bildirimleri al ve eski jolt bildirimlerini sil
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.filter {
            $0.identifier.starts(with: "jolt-") ||
            $0.identifier.starts(with: "routine-") ||
            $0.identifier.starts(with: "dose-")
        }.map(\.identifier)
        
        if !oldIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: oldIds)
            #if DEBUG
            print("🗑️ Removed \(oldIds.count) old notifications")
            #endif
            
            // Silme işleminin tamamlanmasını bekle
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // 3. Aktif routine'ler için bildirimleri planla
        let enabledRoutines = routines.filter { $0.isEnabled }
        guard !enabledRoutines.isEmpty else {
            #if DEBUG
            print("📭 No active routines found")
            #endif
            return
        }
        
        // 4. Hafta sonu modu kontrolü
        let weekendModeEnabled = await MainActor.run {
            UserDefaults.standard.bool(forKey: "weekendModeEnabled")
        }
        
        let calendar = Calendar.current
        let now = Date()
        var scheduledCount = 0
        
        // 5. Her routine için önümüzdeki 7 gün bildirim oluştur
        for routine in enabledRoutines {
            #if DEBUG
            print("🔍 Processing routine: \(routine.name), hour: \(routine.hour), minute: \(routine.minute), days: \(routine.days)")
            #endif
            
            for dayOffset in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                
                let weekday = calendar.component(.weekday, from: targetDate)
                
                // Bu gün routine'in aktif olduğu gün mü?
                guard routine.days.contains(weekday) else { continue }
                
                // Hafta sonu modu aktifse ve Cumartesi/Pazar ise atla
                if weekendModeEnabled && (weekday == 1 || weekday == 7) {
                    continue
                }
                
                // Bildirim zamanını oluştur
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = routine.hour
                components.minute = routine.minute
                
                guard let notificationDate = calendar.date(from: components) else { continue }
                
                // Sadece geçmiş saatleri atla (bugün için gelecek saatler dahil)
                // 30 saniye tolerans - bildirim hemen planlanabilsin
                if notificationDate.addingTimeInterval(30) < now {
                    if dayOffset == 0 {
                        #if DEBUG
                        print("⏭️ Skipping past time: \(notificationDate)")
                        #endif
                    }
                    continue
                }
                
                // O bildirim saatinde Focus'ta kaç içerik olacağını hesapla
                let focusItems = bookmarks.filter { bookmark in
                    bookmark.status == .active && bookmark.scheduledFor <= notificationDate
                }
                let itemCount = focusItems.count
                
                // Focus boşsa bildirim atma
                if itemCount == 0 {
                    #if DEBUG
                    print("📭 Focus will be empty at \(notificationDate), skipping")
                    #endif
                    continue
                }
                
                #if DEBUG
                print("📊 \(itemCount) items will be in Focus at \(notificationDate)")
                #endif
                
                // Bildirim içeriği
                let content = UNMutableNotificationContent()
                content.title = getDynamicTitle(for: routine.hour)
                
                if itemCount == 1, let firstItem = focusItems.first {
                    content.body = firstItem.title
                } else {
                    content.body = "notification.queueReady.body".localized(with: itemCount)
                }
                
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.badge = NSNumber(value: itemCount)
                
                // Trigger
                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                
                // Request ID - unique per routine and time
                let identifier = "dose-\(routine.id.uuidString)-\(Int(notificationDate.timeIntervalSince1970))"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                do {
                    try await center.add(request)
                    #if DEBUG
                    print("📅 Added: \(routine.name) at \(notificationDate)")
                    #endif
                    scheduledCount += 1
                } catch {
                    #if DEBUG
                    print("❌ Failed to add notification: \(error.localizedDescription)")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("✅ Scheduled \(scheduledCount) notifications for \(enabledRoutines.count) routines")
        #endif
        
        // Debug: Bekleyen bildirimleri listele
        #if DEBUG
        await debugPrintPendingNotifications()
        #endif
    }
    
    private func getDynamicTitle(for hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "notification.morning.title".localized
        case 12..<17:
            return "notification.afternoon.title".localized
        default:
            return "notification.evening.title".localized
        }
    }
    
    #if DEBUG
    private func debugPrintPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        print("📋 Pending notifications: \(requests.count)")
        for request in requests.prefix(10) {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let dc = trigger.dateComponents
                print("  - \(request.identifier.prefix(50)): \(dc.year ?? 0)-\(dc.month ?? 0)-\(dc.day ?? 0) \(dc.hour ?? 0):\(dc.minute ?? 0)")
            }
        }
    }
    #endif
}

// MARK: - Convenience Wrapper (MainActor)

/// Ana thread'den çağrılabilir convenience wrapper
@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Bildirimleri planla - ModelContext'ten veri çeker
    func scheduleSmartNotifications(modelContext: ModelContext) {
        // Routine ve Bookmark'ları çek
        let routineDescriptor = FetchDescriptor<Routine>()
        let bookmarkDescriptor = FetchDescriptor<Bookmark>()
        
        guard let routines = try? modelContext.fetch(routineDescriptor),
              let bookmarks = try? modelContext.fetch(bookmarkDescriptor) else {
            #if DEBUG
            print("❌ Failed to fetch data for notification scheduling")
            #endif
            return
        }
        
        // Actor'a gönder
        Task {
            await NotificationScheduler.shared.scheduleNotifications(
                routines: routines,
                bookmarks: bookmarks
            )
        }
    }
    
    /// İzin iste
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        Task {
            let granted = await NotificationScheduler.shared.requestPermission()
            completion?(granted)
        }
    }
    
    /// İzin durumunu kontrol et
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        Task {
            let status = await NotificationScheduler.shared.checkPermission()
            completion(status)
        }
    }
    
    /// Tüm bildirimleri iptal et
    func cancelAllNotifications() {
        Task {
            await NotificationScheduler.shared.cancelAllNotifications()
        }
    }
    
    /// Update app badge with current focus count (only items ready to read)
    func updateBadgeCount(modelContext: ModelContext) {
        let now = Date()
        
        // Count active bookmarks that are ready (scheduledFor <= now)
        let descriptor = FetchDescriptor<Bookmark>()
        guard let allBookmarks = try? modelContext.fetch(descriptor) else {
            return
        }
        
        let readyCount = allBookmarks.filter { bookmark in
            bookmark.status == .active && bookmark.scheduledFor <= now
        }.count
        
        // Update badge
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(readyCount)
                #if DEBUG
                print("📛 Badge updated: \(readyCount)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update badge: \(error)")
                #endif
            }
        }
    }
    
    /// Schedule streak protection notification for 20:00 if user has streak >= 3 and hasn't read today
    func scheduleStreakProtectionNotification(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        let currentStreak = defaults.integer(forKey: "currentStreak")
        let lastJoltDateString = defaults.string(forKey: "lastJoltDate") ?? ""
        
        // Only for users with 3+ day streaks
        guard currentStreak >= 3 else { return }
        
        // Check if already jolted today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastJoltDate = ISO8601DateFormatter().date(from: lastJoltDateString) {
            let lastJoltDay = calendar.startOfDay(for: lastJoltDate)
            if lastJoltDay == today {
                // Already read today, no need for reminder
                return
            }
        }
        
        // Schedule notification for 20:00 today (if not past)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        
        guard let notifyDate = calendar.date(from: components), notifyDate > Date() else {
            return
        }
        
        Task {
            let center = UNUserNotificationCenter.current()
            
            // Remove old streak notifications
            let pending = await center.pendingNotificationRequests()
            let oldIds = pending.filter { $0.identifier.starts(with: "jolt-streak-") }.map(\.identifier)
            if !oldIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIds)
            }
            
            let content = UNMutableNotificationContent()
            content.title = "notification.streak.protect.title".localized
            content.body = "notification.streak.protect.body".localized(with: currentStreak)
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.hour, .minute], from: notifyDate),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "jolt-streak-\(today.timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await center.add(request)
                #if DEBUG
                print("🔥 Streak protection notification scheduled for 20:00")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to schedule streak notification: \(error)")
                #endif
            }
        }
    }
    
    /// Hafta sonu modu aktif mi?
    func isWeekendModeActive() -> Bool {
        let weekendModeEnabled = UserDefaults.standard.bool(forKey: "weekendModeEnabled")
        guard weekendModeEnabled else { return false }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Routine'ler değiştiğinde gönderilir
    static let routinesDidChange = Notification.Name("routinesDidChange")
}
