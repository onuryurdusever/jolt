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
    static var title: LocalizedStringResource = "Odak'ı Aç"
    static var description = IntentDescription("Jolt Odak sekmesini açar")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Show Next Bookmark Intent

struct ShowNextBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Sonraki İçeriği Göster"
    static var description = IntentDescription("Okuma listenizde sonraki içeriği gösterir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: "Okuma listeniz boş! Tebrikler 🎉")
        }
        
        if let title = decoded.nextBookmarkTitle,
           let domain = decoded.nextBookmarkDomain,
           let time = decoded.nextBookmarkReadingTime {
            return .result(dialog: "Sıradaki: \(title). \(domain)'dan, \(time) dakikalık okuma.")
        } else {
            return .result(dialog: "Tüm içerikleri okudunuz! Harika iş 🎉")
        }
    }
}

// MARK: - Get Streak Intent

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Okuma Serisi"
    static var description = IntentDescription("Mevcut okuma serinizi gösterir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        
        let dialog: IntentDialog
        switch streak {
        case 0:
            dialog = "Henüz bir okuma seriniz yok. Bugün başlayın!"
        case 1:
            dialog = "1 günlük okuma serisi. Harika başlangıç!"
        case 2...6:
            dialog = "\(streak) günlük okuma serisi. Devam edin!"
        case 7...13:
            dialog = "\(streak) günlük seri! Bir haftayı geçtiniz, muhteşem!"
        case 14...29:
            dialog = "\(streak) günlük seri! İki haftayı aştınız, inanılmaz!"
        default:
            dialog = "\(streak) günlük muazzam seri! Efsanesiniz!"
        }
        
        return .result(dialog: dialog)
    }
}

// MARK: - Get Today Stats Intent

struct GetTodayStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Bugünün İstatistikleri"
    static var description = IntentDescription("Bugün okuduklarınızı gösterir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: "Bugün henüz içerik okumadınız. Şimdi başlayın!")
        }
        
        let todayJolts = decoded.todayJolts
        let totalJolts = decoded.totalJolts
        
        let dialog: IntentDialog
        switch todayJolts {
        case 0:
            dialog = "Bugün henüz içerik okumadınız. Hadi başlayalım!"
        case 1:
            dialog = "Bugün 1 içerik okudunuz. Toplam \(totalJolts) içerik."
        case 2...4:
            dialog = "Bugün \(todayJolts) içerik okudunuz. Güzel gidiyorsunuz! Toplam \(totalJolts)."
        default:
            dialog = "Bugün \(todayJolts) içerik okudunuz! Muhteşem performans! Toplam \(totalJolts)."
        }
        
        return .result(dialog: dialog)
    }
}

// MARK: - Get Pending Count Intent

struct GetPendingCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Bekleyen İçerikler"
    static var description = IntentDescription("Kaç içerik beklediğini gösterir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: "Bekleyen içerik yok!")
        }
        
        let pending = decoded.pendingCount
        
        let dialog: IntentDialog
        switch pending {
        case 0:
            dialog = "Bekleyen içerik yok! Inbox zero başardınız!"
        case 1:
            dialog = "1 içerik bekliyor. Hızlıca halledebilirsiniz!"
        case 2...5:
            dialog = "\(pending) içerik bekliyor. Kısa bir okuma seansı yeterli!"
        case 6...10:
            dialog = "\(pending) içerik bekliyor. Bugün birkaçını okuyun!"
        default:
            dialog = "\(pending) içerik bekliyor. Biraz birikmişler, ama sorun değil!"
        }
        
        return .result(dialog: dialog)
    }
}

// MARK: - Weekly Summary Intent

struct WeeklySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Haftalık Özet"
    static var description = IntentDescription("Bu haftaki okuma özetinizi gösterir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        
        guard let data = defaults?.data(forKey: "widget_data"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .result(dialog: "Henüz veri yok. Okumaya başlayın!")
        }
        
        let total = decoded.totalJolts
        let pending = decoded.pendingCount
        
        let dialog: IntentDialog = """
        Haftalık özet: \(streak) günlük okuma serisi. \
        Toplam \(total) içerik okudunuz. \
        \(pending) içerik bekliyor.
        """
        
        return .result(dialog: dialog)
    }
}

// MARK: - Motivational Quote Intent

struct MotivationIntent: AppIntent {
    static var title: LocalizedStringResource = "Motivasyon"
    static var description = IntentDescription("Okuma motivasyonu verir")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let quotes = [
            "Bugün okuduğunuz bir sayfa, yarın atacağınız bir adımdır.",
            "Okumak zihnin egzersizidir. Bugün kaç tur attınız?",
            "Her okunan makale yeni bir kapı açar.",
            "5 dakikanız var mı? Bir makale okumaya yeter!",
            "Bookmark mezarlığınızı temizleme zamanı!",
            "Bilgi güçtür. Bugün biraz güç toplayın!",
            "Küçük adımlar, büyük değişimler yaratır.",
            "Okuyan insan, düşünen insandır."
        ]
        
        let randomQuote = quotes.randomElement() ?? quotes[0]
        return .result(dialog: "\(randomQuote)")
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
    static var title: LocalizedStringResource = "Sıradakini Ertele"
    static var description = IntentDescription("Sıradaki içeriği bir sonraki rutine erteler")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Save snooze request to UserDefaults - app will handle it when opened
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared")
        defaults?.set(true, forKey: "siri_snooze_request")
        defaults?.set(Date(), forKey: "siri_snooze_request_time")
        
        // Get bookmark title for confirmation
        if let data = defaults?.data(forKey: "widget_data"),
           let decoded = try? JSONDecoder().decode(WidgetData.self, from: data),
           let title = decoded.nextBookmarkTitle {
            return .result(dialog: "\(title) bir sonraki rutine ertelendi.")
        }
        
        return .result(dialog: "Ertelenecek içerik bulunamadı.")
    }
}

// MARK: - Shortcuts Provider

struct JoltShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Aç
        AppShortcut(
            intent: OpenFocusIntent(),
            phrases: [
                "\(.applicationName)'u aç",
                "\(.applicationName) aç",
                "Open \(.applicationName)"
            ],
            shortTitle: "Aç",
            systemImageName: "bolt.fill"
        )
        
        // Sonraki içerik
        AppShortcut(
            intent: ShowNextBookmarkIntent(),
            phrases: [
                "\(.applicationName) sıradaki ne",
                "\(.applicationName) sonraki",
                "\(.applicationName) ne okuyacağım"
            ],
            shortTitle: "Sonraki",
            systemImageName: "book.fill"
        )
        
        // Streak
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "\(.applicationName) serim kaç",
                "\(.applicationName) streak",
                "\(.applicationName) seri"
            ],
            shortTitle: "Seri",
            systemImageName: "flame.fill"
        )
        
        // Bugün
        AppShortcut(
            intent: GetTodayStatsIntent(),
            phrases: [
                "\(.applicationName) bugün kaç",
                "\(.applicationName) bugün",
                "\(.applicationName) günlük"
            ],
            shortTitle: "Bugün",
            systemImageName: "sun.max.fill"
        )
        
        // Bekleyenler
        AppShortcut(
            intent: GetPendingCountIntent(),
            phrases: [
                "\(.applicationName) kaç bekliyor",
                "\(.applicationName) bekleyenler",
                "\(.applicationName) inbox"
            ],
            shortTitle: "Bekleyenler",
            systemImageName: "tray.full.fill"
        )
        
        // Haftalık özet
        AppShortcut(
            intent: WeeklySummaryIntent(),
            phrases: [
                "\(.applicationName) haftalık",
                "\(.applicationName) özet",
                "\(.applicationName) rapor"
            ],
            shortTitle: "Haftalık",
            systemImageName: "calendar"
        )
        
        // Motivasyon
        AppShortcut(
            intent: MotivationIntent(),
            phrases: [
                "\(.applicationName) motive et",
                "\(.applicationName) motivasyon",
                "\(.applicationName) ilham"
            ],
            shortTitle: "Motivasyon",
            systemImageName: "sparkles"
        )
        
        // Ertele
        AppShortcut(
            intent: SnoozeNextBookmarkIntent(),
            phrases: [
                "\(.applicationName) ertele",
                "\(.applicationName) sonra oku",
                "\(.applicationName) şimdi değil"
            ],
            shortTitle: "Ertele",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
