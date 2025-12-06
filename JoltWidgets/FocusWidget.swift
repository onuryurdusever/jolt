//
//  FocusWidget.swift
//  JoltWidgets
//
//  Shows next bookmark to read with quick action
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct FocusEntry: TimelineEntry {
    let date: Date
    let bookmarkTitle: String?
    let bookmarkDomain: String?
    let readingTime: Int?
    let pendingCount: Int
}

// MARK: - Timeline Provider

struct FocusProvider: AppIntentTimelineProvider {
    typealias Entry = FocusEntry
    typealias Intent = FocusWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(
            date: Date(),
            bookmarkTitle: "How to Build Better Habits",
            bookmarkDomain: "medium.com",
            readingTime: 5,
            pendingCount: 12
        )
    }
    
    func snapshot(for configuration: FocusWidgetConfigurationIntent, in context: Context) async -> FocusEntry {
        let data = JoltSharedData.load()
        return FocusEntry(
            date: Date(),
            bookmarkTitle: data.nextBookmarkTitle,
            bookmarkDomain: data.nextBookmarkDomain,
            readingTime: data.nextBookmarkReadingTime,
            pendingCount: data.pendingCount
        )
    }
    
    func timeline(for configuration: FocusWidgetConfigurationIntent, in context: Context) async -> Timeline<FocusEntry> {
        let data = JoltSharedData.load()
        let entry = FocusEntry(
            date: Date(),
            bookmarkTitle: data.nextBookmarkTitle,
            bookmarkDomain: data.nextBookmarkDomain,
            readingTime: data.nextBookmarkReadingTime,
            pendingCount: data.pendingCount
        )
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget View

struct FocusWidgetEntryView: View {
    var entry: FocusProvider.Entry
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
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.widgetJoltYellow)
                
                Text("widget.focus.nextUp".localized)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                Spacer()
                
                if entry.pendingCount > 0 {
                    Text("widget.focus.morePending".localized(with: entry.pendingCount - 1))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            if let title = entry.bookmarkTitle {
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Meta
                HStack(spacing: 8) {
                    if let domain = entry.bookmarkDomain {
                        Text(domain)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    if let time = entry.readingTime {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text("widget.focus.minutesRead".localized(with: time))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.widgetJoltYellow)
                    }
                }
            } else {
                Spacer()
                
                // Empty State
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    
                    Text("widget.focus.allCaughtUp".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Medium Widget
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            if let title = entry.bookmarkTitle {
                // Left: Content
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.widgetJoltYellow)
                        
                        Text("widget.focus.nextUp".localized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                    
                    // Title
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                    
                    Spacer()
                    
                    // Meta
                    HStack(spacing: 12) {
                        if let domain = entry.bookmarkDomain {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 10))
                                Text(domain)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.gray)
                        }
                        
                        if let time = entry.readingTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("time.minutes".localized(with: time))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.widgetJoltYellow)
                        }
                    }
                }
                
                Spacer()
                
                // Right: Action Area
                VStack(spacing: 8) {
                    // Jolt Button Visual
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 56, height: 56)
                        
                        Circle()
                            .fill(Color.widgetCardBackground)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.widgetJoltYellow)
                    }
                    
                    Text("widget.focus.tapToRead".localized)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                }
                
            } else {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("widget.focus.allCaughtUp".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("widget.focus.shareToAdd".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .containerBackground(Color.widgetBackground, for: .widget)
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16))
            
            if let title = entry.bookmarkTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    
                    if let time = entry.readingTime {
                        Text("widget.focus.minutesReadLong".localized(with: time))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("widget.focus.allCaughtUp".localized)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Definition

struct FocusWidget: Widget {
    let kind: String = "FocusWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: FocusWidgetConfigurationIntent.self,
            provider: FocusProvider()
        ) { entry in
            FocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Read")
        .description("Shows your next bookmark to read")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Deep Link URL

extension URL {
    static func joltOpenBookmark() -> URL {
        URL(string: "jolt://focus")!
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FocusWidget()
} timeline: {
    FocusEntry(
        date: .now,
        bookmarkTitle: "How to Build Better Habits with Atomic Habits",
        bookmarkDomain: "medium.com",
        readingTime: 5,
        pendingCount: 12
    )
}

#Preview(as: .systemMedium) {
    FocusWidget()
} timeline: {
    FocusEntry(
        date: .now,
        bookmarkTitle: "The Future of Swift Concurrency",
        bookmarkDomain: "swift.org",
        readingTime: 8,
        pendingCount: 7
    )
}

#Preview(as: .systemSmall) {
    FocusWidget()
} timeline: {
    FocusEntry(
        date: .now,
        bookmarkTitle: nil,
        bookmarkDomain: nil,
        readingTime: nil,
        pendingCount: 0
    )
}
