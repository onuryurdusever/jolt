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
    static let title: LocalizedStringResource = "widget.streak.name"
    static let description = IntentDescription("widget.streak.desc")
}

struct FocusWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.focus.name"
    static let description = IntentDescription("widget.focus.desc")
}



struct StatsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.stats.name"
    static let description = IntentDescription("widget.stats.desc")
}

struct QuoteWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.quote.name"
    static let description = IntentDescription("widget.quote.desc")
}

