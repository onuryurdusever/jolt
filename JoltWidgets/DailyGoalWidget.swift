//
//  DailyGoalWidget.swift
//  JoltWidgets
//
//  Shows daily reading goal progress
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DailyGoalEntry: TimelineEntry {
    let date: Date
    let todayJolts: Int
    let dailyGoal: Int
    let currentStreak: Int
}

// MARK: - Timeline Provider

struct DailyGoalProvider: AppIntentTimelineProvider {
    typealias Entry = DailyGoalEntry
    typealias Intent = DailyGoalWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> DailyGoalEntry {
        DailyGoalEntry(date: Date(), todayJolts: 2, dailyGoal: 3, currentStreak: 5)
    }
    
    func snapshot(for configuration: DailyGoalWidgetConfigurationIntent, in context: Context) async -> DailyGoalEntry {
        let data = JoltSharedData.load()
        return DailyGoalEntry(
            date: Date(),
            todayJolts: data.todayJolts,
            dailyGoal: data.dailyGoalTarget, // Use dailyGoalTarget (the actual goal setting)
            currentStreak: data.currentStreak
        )
    }
    
    func timeline(for configuration: DailyGoalWidgetConfigurationIntent, in context: Context) async -> Timeline<DailyGoalEntry> {
        let data = JoltSharedData.load()
        let entry = DailyGoalEntry(
            date: Date(),
            todayJolts: data.todayJolts,
            dailyGoal: data.dailyGoalTarget, // Use dailyGoalTarget (the actual goal setting)
            currentStreak: data.currentStreak
        )
        
        // Update at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }
}

// MARK: - Widget View

struct DailyGoalWidgetEntryView: View {
    var entry: DailyGoalProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private var progress: Double {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(Double(entry.todayJolts) / Double(entry.dailyGoal), 1.0)
    }
    
    private var isCompleted: Bool {
        entry.todayJolts >= entry.dailyGoal
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
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
        VStack(spacing: 12) {
            // Progress Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isCompleted ? 
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.widgetJoltYellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Center content
                VStack(spacing: 2) {
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(entry.todayJolts)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("/\(entry.dailyGoal)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Label
            Text(isCompleted ? "widget.goal.complete".localized : "widget.dailyGoal.title".localized)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isCompleted ? .green : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Lock Screen Circular
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
            } else {
                Text("\(entry.todayJolts)/\(entry.dailyGoal)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var rectangularView: some View {
        HStack(spacing: 12) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text("\(entry.todayJolts)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isCompleted ? "widget.goal.dailyComplete".localized : "widget.dailyGoal.title".localized)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(isCompleted ? "widget.goal.streakInfo".localized(with: entry.currentStreak) : "widget.goal.remaining".localized(with: entry.dailyGoal - entry.todayJolts))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Definition

struct DailyGoalWidget: Widget {
    let kind: String = "DailyGoalWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DailyGoalWidgetConfigurationIntent.self,
            provider: DailyGoalProvider()
        ) { entry in
            DailyGoalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Günlük Hedef")
        .description("Günlük okuma hedefinizi takip edin")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    DailyGoalWidget()
} timeline: {
    DailyGoalEntry(date: .now, todayJolts: 2, dailyGoal: 3, currentStreak: 5)
    DailyGoalEntry(date: .now, todayJolts: 3, dailyGoal: 3, currentStreak: 6)
}
