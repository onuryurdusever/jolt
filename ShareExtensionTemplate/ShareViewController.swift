//
//  ShareViewController.swift
//  JoltShareExtension
//
//  Created by Onur Yurdusever on 1.12.2025.
//
//  IMPORTANT: This is a template file for Share Extension
//  To add this to your project:
//  1. In Xcode: File > New > Target > Share Extension
//  2. Name it "JoltShareExtension"
//  3. Replace ShareViewController.swift content with this file
//  4. Add App Groups capability: group.com.jolt.shared
//  5. Add SwiftData models to extension target
//

import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications
import LinkPresentation

class ShareViewController: UIViewController {
    private var selectedTime: ScheduledTime?
    private var sharedURL: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SwiftUI view
        let hostingController = UIHostingController(
            rootView: ShareExtensionView(
                onScheduleSelected: { [weak self] time in
                    self?.saveBookmark(scheduledTime: time)
                },
                onCancel: { [weak self] in
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -1))
                }
            )
        )
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
        
        // Extract URL from share context
        extractURL()
    }
    
    private func extractURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            return
        }
        
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                    if let shareURL = url as? URL {
                        DispatchQueue.main.async {
                            self?.sharedURL = shareURL.absoluteString
                        }
                    }
                }
            }
        }
    }
    
    private func saveBookmark(scheduledTime: ScheduledTime) {
        guard let urlString = sharedURL,
              let userID = loadUserID() else {
            extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -2))
            return
        }
        
        // Setup SwiftData in App Group container
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jolt.shared") else {
            print("❌ Failed to get App Group container")
            extensionContext?.cancelRequest(withError: NSError(domain: "com.jolt.share", code: -3))
            return
        }
        
        let schema = Schema([Bookmark.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: appGroupURL.appendingPathComponent("jolt.sqlite"),
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            // Calculate scheduled timestamp (UTC)
            let scheduledFor = calculateScheduledTime(for: scheduledTime)
            let domain = URL(string: urlString)?.host ?? "unknown"
            
            // Create bookmark
            let bookmark = Bookmark(
                userID: userID,
                originalURL: urlString,
                status: .pending,
                scheduledFor: scheduledFor,
                title: domain, // Placeholder, will be updated by parser
                domain: domain
            )
            
            context.insert(bookmark)
            try context.save()
            
            print("✅ Bookmark saved: \(urlString)")
            
            // Schedule notification (if authorized)
            scheduleNotification(for: scheduledFor, title: domain)
            
            // Close extension
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            
        } catch {
            print("❌ Failed to save bookmark: \(error)")
            extensionContext?.cancelRequest(withError: error)
        }
    }
    
    private func calculateScheduledTime(for time: ScheduledTime) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        
        switch time {
        case .morning:
            components.hour = 9
            components.minute = 0
        case .evening:
            components.hour = 21
            components.minute = 0
        case .weekend:
            // Next Saturday
            let today = calendar.startOfDay(for: Date())
            let daysUntilSaturday = (7 - calendar.component(.weekday, from: today) + 7) % 7
            let targetDate = calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)!
            components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = 10
            components.minute = 0
        }
        
        var scheduledDate = calendar.date(from: components) ?? Date()
        
        // If time has passed today, schedule for tomorrow (except weekend)
        if scheduledDate <= Date() && time != .weekend {
            scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? Date()
        }
        
        return scheduledDate
    }
    
    private func scheduleNotification(for date: Date, title: String) {
        // Check if notifications are authorized
        let notificationGranted = UserDefaults(suiteName: "group.com.jolt.shared")?.bool(forKey: "notificationPermissionGranted") ?? false
        
        guard notificationGranted else {
            print("⚠️ Notifications not authorized, skipping")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⚡ Reading Time!"
        content.body = "Time to jolt through your saved content"
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Notification scheduled for \(date)")
            }
        }
    }
    
    private func loadUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jolt.userId",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let userID = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return userID
    }
}

// MARK: - SwiftUI Views

enum ScheduledTime: String, CaseIterable {
    case morning = "☀️ Sabah"
    case evening = "🌙 Akşam"
    case weekend = "📅 Hafta Sonu"
    
    var subtitle: String {
        switch self {
        case .morning: return "09:00"
        case .evening: return "21:00"
        case .weekend: return "Cumartesi 10:00"
        }
    }
}

struct ShareExtensionView: View {
    let onScheduleSelected: (ScheduledTime) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#CCFF00"))
                    
                    Text("When will you read this?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 32)
                
                // Time options
                VStack(spacing: 12) {
                    ForEach(ScheduledTime.allCases, id: \.self) { time in
                        TimeOptionButton(time: time) {
                            onScheduleSelected(time)
                        }
                    }
                }
                
                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
            )
            .padding(.horizontal, 20)
        }
    }
}

struct TimeOptionButton: View {
    let time: ScheduledTime
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(time.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(time.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

// Color extension helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
