//
//  QuoteWidget.swift
//  JoltWidgets
//
//  Shows daily motivational quote
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
    let todayJolts: Int
}

// MARK: - Quotes

struct JoltQuotes {
    static var quotes: [String] {
        (1...15).map { "quote.\($0)".localized }
    }
    
    static func quoteOfTheDay() -> String {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % 15
        return "quote.\(index + 1)".localized
    }
}

// MARK: - Timeline Provider

struct QuoteProvider: AppIntentTimelineProvider {
    typealias Entry = QuoteEntry
    typealias Intent = QuoteWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: JoltQuotes.quotes[0], todayJolts: 0)
    }
    
    func snapshot(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> QuoteEntry {
        let data = JoltSharedData.load()
        return QuoteEntry(
            date: Date(),
            quote: JoltQuotes.quoteOfTheDay(),
            todayJolts: data.todayJolts
        )
    }
    
    func timeline(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> Timeline<QuoteEntry> {
        let data = JoltSharedData.load()
        let entry = QuoteEntry(
            date: Date(),
            quote: JoltQuotes.quoteOfTheDay(),
            todayJolts: data.todayJolts
        )
        
        // Update at midnight for new quote
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }
}

// MARK: - Widget View

struct QuoteWidgetEntryView: View {
    var entry: QuoteProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }
    
    // MARK: - Small Widget
    
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            Image(systemName: "quote.opening")
                .font(.system(size: 14))
                .foregroundColor(.widgetJoltYellow)
            
            Spacer()
            
            // Quote
            Text(entry.quote)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(5)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Jolt branding
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.widgetJoltYellow)
                
                Text("widget.quote.jolt".localized)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Medium Widget
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Quote
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 18))
                    .foregroundColor(.widgetJoltYellow)
                
                Spacer()
                
                Text(entry.quote)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.widgetJoltYellow)
                    
                    Text("widget.quote.dailyInspiration".localized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Today's progress circle
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 2) {
                        Text("\(entry.todayJolts)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("widget.quote.todayLabel".localized)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                
                Text("widget.quote.startReading".localized)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.widgetJoltYellow)
            }
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 14))
            
            Text(entry.quote)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Definition

struct QuoteWidget: Widget {
    let kind: String = "QuoteWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuoteWidgetConfigurationIntent.self,
            provider: QuoteProvider()
        ) { entry in
            QuoteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.quote.name".localized)
        .description("widget.quote.desc".localized)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    QuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "Bugün okuduğunuz bir sayfa, yarın atacağınız bir adımdır.", todayJolts: 2)
}

#Preview(as: .systemMedium) {
    QuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "Okumak zihnin egzersizidir. Bugün kaç tur attınız?", todayJolts: 3)
}
