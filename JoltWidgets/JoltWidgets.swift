//
//  JoltWidgets.swift
//  JoltWidgets
//
//  Widget bundle for Jolt app
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Bundle

@main
struct JoltWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        FocusWidget()
        StatsWidget()
        QuoteWidget()

    }
}

// MARK: - Widget Colors

extension Color {
    static let widgetBackground = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let widgetCardBackground = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let widgetJoltYellow = Color(red: 1.0, green: 0.84, blue: 0.04)
}

// MARK: - Configuration Intents

struct StreakWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Okuma Serisi"
    static var description = IntentDescription("Günlük okuma serinizi takip edin")
}

struct FocusWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sıradaki"
    static var description = IntentDescription("Bir sonraki içeriğinizi görün")
}



struct StatsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "İstatistikler"
    static var description = IntentDescription("Haftalık okuma performansınız")
}

struct QuoteWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Günlük İlham"
    static var description = IntentDescription("Günün motivasyon sözü")
}

