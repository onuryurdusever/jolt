//
//  StatsWidget.swift
//  JoltWidgets
//
//  Shows weekly reading activity graph
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let weeklyActivity: [Int] // Last 7 days [today, -1, -2, -3, -4, -5, -6]
    let totalJolts: Int
    let currentStreak: Int
    let longestStreak: Int
}

// MARK: - Timeline Provider

struct StatsProvider: AppIntentTimelineProvider {
    typealias Entry = StatsEntry
    typealias Intent = StatsWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(
            date: Date(),
            weeklyActivity: [3, 2, 4, 1, 3, 2, 5],
            totalJolts: 42,
            currentStreak: 7,
            longestStreak: 14
        )
    }
    
    func snapshot(for configuration: StatsWidgetConfigurationIntent, in context: Context) async -> StatsEntry {
        let data = JoltSharedData.load()
        return StatsEntry(
            date: Date(),
            weeklyActivity: data.weeklyActivity,
            totalJolts: data.totalJolts,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak
        )
    }
    
    func timeline(for configuration: StatsWidgetConfigurationIntent, in context: Context) async -> Timeline<StatsEntry> {
        let data = JoltSharedData.load()
        let entry = StatsEntry(
            date: Date(),
            weeklyActivity: data.weeklyActivity,
            totalJolts: data.totalJolts,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak
        )
        
        // Update at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }
}

// MARK: - Widget View

struct StatsWidgetEntryView: View {
    var entry: StatsProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private var maxActivity: Int {
        max(entry.weeklyActivity.max() ?? 1, 1)
    }
    
    private var weekDays: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        var days: [String] = []
        let calendar = Calendar.current
        
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                formatter.dateFormat = "EEE"
                let dayName = formatter.string(from: date)
                days.append(String(dayName.prefix(2)))
            }
        }
        return days
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }
    
    // MARK: - Lock Screen Circular
    
    private var circularView: some View {
        let todayJolts = entry.weeklyActivity.first ?? 0
        
        return ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 0) {
                Text("\(todayJolts)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("widget.stats.jolt".localized)
                    .font(.system(size: 8, weight: .medium))
            }
        }
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var rectangularView: some View {
        let todayJolts = entry.weeklyActivity.first ?? 0
        let weeklyTotal = entry.weeklyActivity.reduce(0, +)
        
        return HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("widget.stats.todayJolts".localized(with: todayJolts))
                    .font(.system(size: 12, weight: .semibold))
                
                Text("widget.stats.weeklyTotal".localized(with: weeklyTotal))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Small Widget
    
    private var smallView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.widgetJoltYellow)
                
                Text("widget.stats.weekly".localized)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                Spacer()
            }
            
            // Bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(entry.weeklyActivity.reversed().enumerated()), id: \.offset) { index, count in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                index == 6 ? 
                                    LinearGradient(colors: [.widgetJoltYellow, .orange], startPoint: .bottom, endPoint: .top) :
                                    LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                            )
                            .frame(width: 12, height: barHeight(for: count))
                        
                        // Day label
                        Text(weekDays[index])
                            .font(.system(size: 8))
                            .foregroundColor(index == 6 ? .white : .gray)
                    }
                }
            }
            .frame(height: 60)
            
            // Total
            Text("widget.stats.thisWeek".localized(with: entry.weeklyActivity.reduce(0, +)))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Medium Widget
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Bar chart
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.widgetJoltYellow)
                    
                    Text("widget.stats.weekly".localized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                }
                
                // Bar chart
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(entry.weeklyActivity.reversed().enumerated()), id: \.offset) { index, count in
                        VStack(spacing: 4) {
                            // Count label
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(index == 6 ? .widgetJoltYellow : .gray)
                            }
                            
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    index == 6 ?
                                        LinearGradient(colors: [.widgetJoltYellow, .orange], startPoint: .bottom, endPoint: .top) :
                                        LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                                )
                                .frame(width: 16, height: barHeightMedium(for: count))
                            
                            // Day label
                            Text(weekDays[index])
                                .font(.system(size: 9))
                                .foregroundColor(index == 6 ? .white : .gray)
                        }
                    }
                }
                .frame(height: 80)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Right: Stats
            VStack(alignment: .leading, spacing: 12) {
                StatItem(
                    icon: "bolt.fill",
                    value: "\(entry.totalJolts)",
                    label: "widget.stats.total".localized,
                    color: .widgetJoltYellow
                )
                
                StatItem(
                    icon: "flame.fill",
                    value: "\(entry.currentStreak)",
                    label: "widget.stats.streak".localized,
                    color: .orange
                )
                
                StatItem(
                    icon: "trophy.fill",
                    value: "\(entry.longestStreak)",
                    label: "widget.stats.best".localized,
                    color: .yellow
                )
            }
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Helpers
    
    private func barHeight(for count: Int) -> CGFloat {
        let maxHeight: CGFloat = 40
        let minHeight: CGFloat = 4
        guard maxActivity > 0 else { return minHeight }
        
        if count == 0 { return minHeight }
        return max(minHeight, CGFloat(count) / CGFloat(maxActivity) * maxHeight)
    }
    
    private func barHeightMedium(for count: Int) -> CGFloat {
        let maxHeight: CGFloat = 50
        let minHeight: CGFloat = 4
        guard maxActivity > 0 else { return minHeight }
        
        if count == 0 { return minHeight }
        return max(minHeight, CGFloat(count) / CGFloat(maxActivity) * maxHeight)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Widget Definition

struct StatsWidget: Widget {
    let kind: String = "StatsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StatsWidgetConfigurationIntent.self,
            provider: StatsProvider()
        ) { entry in
            StatsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.stats.name".localized)
        .description("widget.stats.desc".localized)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StatsWidget()
} timeline: {
    StatsEntry(date: .now, weeklyActivity: [3, 2, 4, 1, 3, 2, 5], totalJolts: 42, currentStreak: 7, longestStreak: 14)
}

#Preview(as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsEntry(date: .now, weeklyActivity: [3, 2, 4, 1, 3, 2, 5], totalJolts: 42, currentStreak: 7, longestStreak: 14)
}
