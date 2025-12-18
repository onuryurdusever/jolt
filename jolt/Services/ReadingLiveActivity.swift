//
//  ReadingLiveActivity.swift
//  jolt
//
//  Live Activity for reading sessions
//

import ActivityKit
import WidgetKit
import SwiftUI
import Combine

// MARK: - Activity Attributes

struct ReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var minutesRemaining: Int
        var startTime: Date
    }
    
    var bookmarkTitle: String
    var bookmarkDomain: String
    var totalMinutes: Int
}

// MARK: - Live Activity Widget

struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            // Lock Screen / Banner View
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                        
                        Text("liveActivity.reading".localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("~\(context.state.minutesRemaining)m")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.yellow)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text(context.attributes.bookmarkTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(Color.yellow)
                                    .frame(width: geometry.size.width * context.state.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("liveActivity.minutesRemaining".localized(with: context.state.minutesRemaining))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
            } compactTrailing: {
                Text("liveActivity.minutesRemaining".localized(with: context.state.minutesRemaining))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.yellow)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<ReadingActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Icon + Title
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                    
                    Text(context.attributes.bookmarkTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Time Remaining
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("liveActivity.minutesRemaining".localized(with: context.state.minutesRemaining))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.yellow)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * context.state.progress, height: 6)
                }
            }
            .frame(height: 6)
            
            // Footer
            HStack {
                Text(context.attributes.bookmarkDomain)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("liveActivity.percentComplete".localized(with: Int(context.state.progress * 100)))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.06, green: 0.06, blue: 0.06))
    }
}

// MARK: - Live Activity Manager

@MainActor
class ReadingActivityManager: ObservableObject {
    static let shared = ReadingActivityManager()
    
    @Published var currentActivity: Activity<ReadingActivityAttributes>?
    
    private init() {}
    
    // MARK: - Start Activity
    
    func startActivity(for bookmark: (title: String, domain: String, totalMinutes: Int)) {
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities not enabled")
            return
        }
        
        // End any existing activity
        Task {
            await endActivity()
        }
        
        let attributes = ReadingActivityAttributes(
            bookmarkTitle: bookmark.title,
            bookmarkDomain: bookmark.domain,
            totalMinutes: bookmark.totalMinutes
        )
        
        let initialState = ReadingActivityAttributes.ContentState(
            progress: 0.0,
            minutesRemaining: bookmark.totalMinutes,
            startTime: Date()
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Started reading activity: \(activity.id)")
        } catch {
            print("❌ Failed to start activity: \(error)")
        }
    }
    
    // MARK: - Update Progress
    
    func updateProgress(_ progress: Double, totalMinutes: Int) {
        guard let activity = currentActivity else { return }
        
        let remaining = Int(Double(totalMinutes) * (1.0 - progress))
        
        let state = ReadingActivityAttributes.ContentState(
            progress: progress,
            minutesRemaining: max(1, remaining),
            startTime: Date()
        )
        
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }
    
    // MARK: - End Activity
    
    func endActivity(showCompletion: Bool = false) async {
        guard let activity = currentActivity else { return }
        
        if showCompletion {
            // Show completion state briefly
            let finalState = ReadingActivityAttributes.ContentState(
                progress: 1.0,
                minutesRemaining: 0,
                startTime: Date()
            )
            
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 5))
        } else {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
        print("✅ Ended reading activity")
    }
    
    // MARK: - End All Activities
    
    func endAllActivities() async {
        for activity in Activity<ReadingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: ReadingActivityAttributes(
    bookmarkTitle: "How to Build Better Habits with Atomic Habits",
    bookmarkDomain: "medium.com",
    totalMinutes: 8
)) {
    ReadingLiveActivity()
} contentStates: {
    ReadingActivityAttributes.ContentState(
        progress: 0.35,
        minutesRemaining: 5,
        startTime: Date()
    )
}
