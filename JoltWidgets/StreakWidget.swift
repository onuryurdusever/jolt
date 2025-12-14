//
//  StreakWidget.swift
//  JoltWidgets
//
//  Displays current reading streak
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let todayJolts: Int
    let totalJolts: Int
}

// MARK: - Timeline Provider

struct StreakProvider: AppIntentTimelineProvider {
    typealias Entry = StreakEntry
    typealias Intent = StreakWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 7,
            todayJolts: 3,
            totalJolts: 42
        )
    }
    
    func snapshot(for configuration: StreakWidgetConfigurationIntent, in context: Context) async -> StreakEntry {
        let data = JoltSharedData.load()
        return StreakEntry(
            date: Date(),
            currentStreak: data.currentStreak,
            todayJolts: data.todayJolts,
            totalJolts: data.totalJolts
        )
    }
    
    func timeline(for configuration: StreakWidgetConfigurationIntent, in context: Context) async -> Timeline<StreakEntry> {
        let data = JoltSharedData.load()
        let entry = StreakEntry(
            date: Date(),
            currentStreak: data.currentStreak,
            todayJolts: data.todayJolts,
            totalJolts: data.totalJolts
        )
        
        // Update at midnight for streak changes
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }
}

// MARK: - Widget View

struct StreakWidgetEntryView: View {
    var entry: StreakProvider.Entry
    @Environment(\.widgetFamily) var family
    
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
    
    // MARK: - Small Widget
    
    private var smallView: some View {
        VStack(spacing: 8) {
            // Streak Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(entry.currentStreak) / 7.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.widgetJoltYellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            Text("widget.streak.dayStreak".localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Medium Widget
    
    private var mediumView: some View {
        HStack(spacing: 20) {
            // Streak Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(entry.currentStreak) / 7.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.widgetJoltYellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("widget.streak".localized)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "bolt.fill", value: "\(entry.todayJolts)", label: "widget.streak.today".localized, color: .widgetJoltYellow)
                StatRow(icon: "checkmark.circle.fill", value: "\(entry.totalJolts)", label: "widget.streak.total".localized, color: .green)
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Lock Screen Circular
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                
                Text("\(entry.currentStreak)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
        }
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("widget.streak.dayStreakCount".localized(with: entry.currentStreak))
                    .font(.system(size: 14, weight: .semibold))
                
                Text("widget.streak.joltsToday".localized(with: entry.todayJolts))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat Row Helper

struct StatRow: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Widget Definition

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StreakWidgetConfigurationIntent.self,
            provider: StreakProvider()
        ) { entry in
            StreakWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.streak.name".localized)
        .description("widget.streak.desc".localized)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, currentStreak: 5, todayJolts: 2, totalJolts: 42)
}

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, currentStreak: 7, todayJolts: 3, totalJolts: 56)
}
