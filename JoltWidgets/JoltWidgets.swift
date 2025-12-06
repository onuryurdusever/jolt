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
        DailyGoalWidget()
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
    static var title: LocalizedStringResource = "Streak Widget"
    static var description = IntentDescription("Shows your current reading streak")
}

struct FocusWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Focus Widget"
    static var description = IntentDescription("Shows your next bookmark to read")
}

struct DailyGoalWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Daily Goal Widget"
    static var description = IntentDescription("Shows your daily reading goal progress")
}

struct StatsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Stats Widget"
    static var description = IntentDescription("Shows your weekly reading activity")
}

struct QuoteWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Quote Widget"
    static var description = IntentDescription("Shows daily motivational quote")
}
