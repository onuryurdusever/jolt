import UserNotifications
import SwiftData
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                    UserDefaults(suiteName: "group.com.jolt.shared")?.set(true, forKey: "notificationPermissionGranted")
                } else {
                    print("❌ Notification permission denied")
                    UserDefaults(suiteName: "group.com.jolt.shared")?.set(false, forKey: "notificationPermissionGranted")
                }
            }
        }
    }
    
    func scheduleSmartNotifications(modelContext: ModelContext) {
        let center = UNUserNotificationCenter.current()
        
        // 1. Cancel all existing routine/smart notifications
        center.getPendingNotificationRequests { requests in
            let oldIds = requests.filter { $0.identifier.starts(with: "jolt-smart-") || $0.identifier.starts(with: "routine-") }.map { $0.identifier }
            if !oldIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIds)
                print("🗑️ Removed \(oldIds.count) old notifications")
            }
            
            // 2. Fetch pending/ready bookmarks with future schedule
            let now = Date()
            let pendingStatus = BookmarkStatus.pending
            let readyStatus = BookmarkStatus.ready
            
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate<Bookmark> { bookmark in
                    (bookmark.status == pendingStatus || bookmark.status == readyStatus) && bookmark.scheduledFor > now
                },
                sortBy: [SortDescriptor(\.scheduledFor)]
            )
            
            guard let bookmarks = try? modelContext.fetch(descriptor) else { return }
            
            // 3. Group by time (rounded to minute)
            let grouped = Dictionary(grouping: bookmarks) { bookmark -> Date in
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: bookmark.scheduledFor)
                return Calendar.current.date(from: components) ?? bookmark.scheduledFor
            }
            
            // 4. Schedule one notification per group
            for (date, items) in grouped {
                let content = UNMutableNotificationContent()
                
                if items.count == 1, let item = items.first {
                    content.title = "notification.timeToRead.title".localized
                    content.body = "notification.timeToRead.body".localized(with: item.title)
                } else {
                    content.title = "notification.queueReady.title".localized
                    content.body = "notification.queueReady.body".localized(with: items.count)
                }
                
                content.sound = .default
                content.interruptionLevel = .active
                
                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let identifier = "jolt-smart-\(Int(date.timeIntervalSince1970))"
                
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule smart notification: \(error)")
                    }
                }
            }
            
            print("✅ Scheduled \(grouped.count) smart notifications based on \(bookmarks.count) items")
        }
    }
    
    // Deprecated: Old dumb scheduler
    // func scheduleRoutineNotifications(routines: [Routine]) { ... }
    
    func scheduleOneOffNotification(for date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
