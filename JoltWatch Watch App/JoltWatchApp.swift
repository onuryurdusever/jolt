//
//  JoltWatchApp.swift
//  JoltWatch Watch App
//
//  Companion app for Jolt on Apple Watch
//

import SwiftUI
import WatchConnectivity

@main
struct JoltWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Streak Card
                    StreakCard(streak: connectivity.currentStreak)
                    
                    // Today Stats
                    TodayStatsCard(
                        todayJolts: connectivity.todayJolts,
                        pendingCount: connectivity.pendingCount
                    )
                    
                    // Next Bookmark
                    if let nextBookmark = connectivity.nextBookmark {
                        NextBookmarkCard(bookmark: nextBookmark)
                    } else {
                        AllCaughtUpCard()
                    }
                    
                    // Quick Action
                    OpenPhoneButton()
                }
                .padding()
            }
            .navigationTitle("Jolt")
        }
        .onAppear {
            connectivity.requestUpdate()
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let streak: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(streak) / 7.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("\(streak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            
            Text("watch.dayStreak".localized)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Today Stats Card

struct TodayStatsCard: View {
    let todayJolts: Int
    let pendingCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(todayJolts)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                
                Text("watch.today".localized)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack(spacing: 4) {
                Text("\(pendingCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("watch.pending".localized)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Next Bookmark Card

struct NextBookmarkCard: View {
    let bookmark: WatchBookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                
                Text("watch.nextUp".localized)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            Text(bookmark.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
            
            HStack(spacing: 6) {
                Text(bookmark.domain)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("\(bookmark.readingTime)m")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.yellow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - All Caught Up Card

struct AllCaughtUpCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            Text("watch.allCaughtUp".localized)
                .font(.system(size: 12, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Open Phone Button

struct OpenPhoneButton: View {
    var body: some View {
        Button {
            // This would trigger a handoff to the iPhone app
        } label: {
            HStack {
                Image(systemName: "iphone")
                    .font(.system(size: 12))
                Text("watch.openOnIPhone".localized)
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
