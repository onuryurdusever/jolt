//
//  PulseView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData
import WidgetKit

struct PulseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allBookmarks: [Bookmark]
    @Query private var allCollections: [Collection]
    @Query private var allRoutines: [Routine]
    
    @AppStorage("currentStreak") private var currentStreak = 0
    @AppStorage("previousStreak") private var previousStreak = 0
    @AppStorage("longestStreak") private var longestStreak = 0
    @AppStorage("lastJoltDate") private var lastJoltDateString = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("dailyGoalTarget") private var dailyGoalTarget = 3
    
    @State private var showSettings = false
    @State private var showRoutinesSettings = false
    @State private var showLogoutAlert = false
    @State private var showAchievementDetail: Achievement?
    @State private var animateStreak = false
    @State private var showLanguagePicker = false
    
    // MARK: - Computed Properties
    
    private var archivedBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .archived }
    }
    
    private var totalJolts: Int {
        archivedBookmarks.count
    }
    
    private var totalReadingTimeMinutes: Int {
        archivedBookmarks.reduce(0) { $0 + $1.readingTimeMinutes }
    }
    
    private var socialJolts: Int {
        archivedBookmarks.filter { $0.type == .social }.count
    }
    
    private var articleJolts: Int {
        archivedBookmarks.filter { $0.type == .article }.count
    }
    
    private var todayJolts: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return archivedBookmarks.filter { bookmark in
            guard let readAt = bookmark.readAt else { return false }
            return calendar.isDate(readAt, inSameDayAs: today)
        }.count
    }
    
    private var lastJoltHour: Int? {
        guard let lastBookmark = archivedBookmarks.sorted(by: { ($0.readAt ?? Date.distantPast) > ($1.readAt ?? Date.distantPast) }).first,
              let readAt = lastBookmark.readAt else { return nil }
        return Calendar.current.component(.hour, from: readAt)
    }
    
    private var weeklyActivity: [Date: Int] {
        let calendar = Calendar.current
        var activity: [Date: Int] = [:]
        
        // Initialize last 7 days with 0
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                activity[startOfDay] = 0
            }
        }
        
        // Count jolts per day
        for bookmark in archivedBookmarks {
            guard let readAt = bookmark.readAt else { continue }
            let startOfDay = calendar.startOfDay(for: readAt)
            if activity[startOfDay] != nil {
                activity[startOfDay, default: 0] += 1
            }
        }
        
        return activity
    }
    
    private var topDomains: [(String, Int)] {
        var domainCounts: [String: Int] = [:]
        for bookmark in archivedBookmarks {
            domainCounts[bookmark.domain, default: 0] += 1
        }
        return domainCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    private var contentMix: [(BookmarkType, Int)] {
        var typeCounts: [BookmarkType: Int] = [:]
        for bookmark in archivedBookmarks {
            typeCounts[bookmark.type, default: 0] += 1
        }
        return typeCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    private var favoriteReadingHour: Int? {
        var hourCounts: [Int: Int] = [:]
        for bookmark in archivedBookmarks {
            guard let readAt = bookmark.readAt else { continue }
            let hour = Calendar.current.component(.hour, from: readAt)
            hourCounts[hour, default: 0] += 1
        }
        return hourCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private var averageReadingTime: Double {
        guard !archivedBookmarks.isEmpty else { return 0 }
        return Double(totalReadingTimeMinutes) / Double(archivedBookmarks.count)
    }
    
    private var streakHealthPercentage: Int {
        // Based on current streak vs 7 day target
        return min(Int((Double(currentStreak) / 7.0) * 100), 100)
    }
    
    private var motivationalMessage: String {
        switch currentStreak {
        case 0: return "pulse.motivation.start".localized
        case 1: return "pulse.motivation.day1".localized
        case 2...3: return "pulse.motivation.days2_3".localized
        case 4...6: return "pulse.motivation.days4_6".localized
        case 7...13: return "pulse.motivation.week".localized
        case 14...29: return "pulse.motivation.twoWeeks".localized
        default: return "pulse.motivation.unstoppable".localized
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        pulseHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Hero Streak Card
                        heroStreakCard
                            .padding(.horizontal, 20)
                        
                        // Stats Grid
                        statsGrid
                            .padding(.horizontal, 20)
                        
                        // Weekly Activity
                        weeklyActivitySection
                            .padding(.horizontal, 20)
                        
                        // Achievements
                        achievementsSection
                            .padding(.horizontal, 20)
                        
                        // Reading Insights
                        readingInsightsSection
                            .padding(.horizontal, 20)
                        
                        // Quick Settings
                        quickSettingsSection
                            .padding(.horizontal, 20)
                        
                        // Footer
                        footerSection
                            .padding(.top, 12)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showRoutinesSettings) {
                NavigationStack {
                    RoutinesSettingsView()
                }
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerView()
            }
            .alert("alert.logout.title".localized, isPresented: $showLogoutAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("settings.logout".localized, role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("alert.logout.message".localized)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                    animateStreak = true
                }
                updateLongestStreak()
                checkAchievements()
            }
            .onChange(of: dailyGoalTarget) { _, newValue in
                // Update widgets when daily goal changes
                Task { @MainActor in
                    WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var pulseHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("pulse.title".localized)
                .font(.iosFootnote)
                .foregroundColor(.joltMutedForeground)
                .tracking(1)
            
            Text("pulse.subtitle".localized)
                .font(.iosLargeTitle)
                .foregroundColor(.joltForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Hero Streak Card
    
    private var heroStreakCard: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.joltMuted, lineWidth: 14)
                    .frame(width: 180, height: 180)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: animateStreak ? CGFloat(min(currentStreak, 7)) / 7.0 : 0)
                    .stroke(
                        LinearGradient(
                            colors: [Color.joltYellow, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animateStreak)
                
                // Center Content
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("\(currentStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.joltForeground)
                    
                    Text("pulse.dayStreak".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                        .tracking(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(A11y.Pulse.streak(days: currentStreak))
            
            VStack(spacing: 8) {
                Text(motivationalMessage)
                    .font(.iosHeadline)
                    .foregroundColor(.joltForeground)
                    .multilineTextAlignment(.center)
                
                if longestStreak > currentStreak {
                    Text("pulse.personalBest".localized(with: longestStreak))
                        .font(.iosCaption1)
                        .foregroundColor(.joltMutedForeground)
                }
            }
            .accessibilityElement(children: .combine)
            
            // Streak Repair Button
            if currentStreak == 1 && previousStreak > 0 {
                Button {
                    repairStreak()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("pulse.repairStreak".localized)
                    }
                    .font(.iosFootnote)
                    .foregroundColor(.joltYellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.joltYellow.opacity(0.15))
                    .cornerRadius(20)
                }
                .accessibilityLabel("a11y.pulse.repairStreak".localized)
                .accessibilityHint("a11y.pulse.repairStreakHint".localized(with: previousStreak))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.joltCardBackground)
        .cornerRadius(24)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pulse.yourStats".localized)
                .font(.iosTitle3)
                .foregroundColor(.joltForeground)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                PulseStatCard(
                    icon: "bolt.fill",
                    iconColor: .joltYellow,
                    value: "\(totalJolts)",
                    label: "pulse.totalJolts".localized
                )
                
                PulseStatCard(
                    icon: "clock.fill",
                    iconColor: Color(red: 0.2, green: 0.78, blue: 0.35),
                    value: formatReadingTime(totalReadingTimeMinutes),
                    label: "pulse.timeInvested".localized
                )
                
                PulseStatCard(
                    icon: "target",
                    iconColor: Color(red: 0.35, green: 0.48, blue: 1),
                    value: "\(todayJolts)/\(dailyGoalTarget)",
                    label: "pulse.dailyGoal".localized
                )
                
                PulseStatCard(
                    icon: "folder.fill",
                    iconColor: .purple,
                    value: "\(allCollections.count)",
                    label: "pulse.collections".localized
                )
            }
        }
    }
    
    // MARK: - Weekly Activity
    
    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("pulse.thisWeek".localized)
                    .font(.iosTitle3)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Text("pulse.joltsCount".localized(with: weeklyActivity.values.reduce(0, +)))
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
            }
            
            HStack(spacing: 8) {
                ForEach(sortedWeekDays, id: \.self) { date in
                    WeekDayBar(
                        date: date,
                        count: weeklyActivity[date] ?? 0,
                        maxCount: weeklyActivity.values.max() ?? 1
                    )
                }
            }
            .padding(20)
            .background(Color.joltCardBackground)
            .cornerRadius(20)
        }
    }
    
    private var sortedWeekDays: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -(6 - dayOffset), to: Date())
        }.map { calendar.startOfDay(for: $0) }
    }
    
    // MARK: - Achievements
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("pulse.achievements".localized)
                    .font(.iosTitle3)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                let unlockedCount = Achievement.allCases.filter { AchievementManager.shared.isUnlocked($0) }.count
                Text("\(unlockedCount)/\(Achievement.allCases.count)")
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            isUnlocked: AchievementManager.shared.isUnlocked(achievement),
                            progress: AchievementManager.shared.getProgress(
                                for: achievement,
                                totalJolts: totalJolts,
                                currentStreak: currentStreak,
                                longestStreak: longestStreak,
                                collectionsCount: allCollections.count,
                                socialJolts: socialJolts,
                                articleJolts: articleJolts,
                                todayJolts: todayJolts
                            )
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Reading Insights
    
    private var readingInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pulse.insights".localized)
                .font(.iosTitle3)
                .foregroundColor(.joltForeground)
            
            VStack(spacing: 0) {
                // Top Sources
                if !topDomains.isEmpty {
                    InsightRow(
                        icon: "globe",
                        title: "pulse.topSources".localized,
                        value: topDomains.prefix(3).map { $0.0 }.joined(separator: ", ")
                    )
                    Divider().background(Color.joltBorder).padding(.leading, 52)
                }
                
                // Favorite Time
                if let hour = favoriteReadingHour {
                    InsightRow(
                        icon: "clock",
                        title: "pulse.favoriteTime".localized,
                        value: formatHour(hour)
                    )
                    Divider().background(Color.joltBorder).padding(.leading, 52)
                }
                
                // Average Read Time
                InsightRow(
                    icon: "timer",
                    title: "pulse.avgReadTime".localized,
                    value: String(format: "%.1f min", averageReadingTime)
                )
                
                // Content Mix
                if !contentMix.isEmpty {
                    Divider().background(Color.joltBorder).padding(.leading, 52)
                    InsightRow(
                        icon: "chart.pie",
                        title: "pulse.contentMix".localized,
                        value: contentMix.prefix(2).map { "\($0.0.rawValue.capitalized)" }.joined(separator: ", ")
                    )
                    
                }
            }
            .padding(.vertical, 4)
            .background(Color.joltCardBackground)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Quick Settings
    
    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.title".localized)
                .font(.iosTitle3)
                .foregroundColor(.joltForeground)
            
            VStack(spacing: 0) {
                // Daily Goal Setting
                DailyGoalSettingRow(dailyGoalTarget: $dailyGoalTarget)
                Divider().background(Color.joltBorder).padding(.leading, 52)
                
                QuickSettingRow(icon: "clock.arrow.circlepath", title: "settings.routines".localized) {
                    showRoutinesSettings = true
                }
                Divider().background(Color.joltBorder).padding(.leading, 52)
                
                QuickSettingRow(icon: "globe", title: "settings.language".localized, subtitle: LanguageManager.shared.currentLanguage.displayName) {
                    showLanguagePicker = true
                }
                Divider().background(Color.joltBorder).padding(.leading, 52)
                
                QuickSettingRow(icon: "bell.fill", title: "settings.notifications".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Divider().background(Color.joltBorder).padding(.leading, 52)
                
                QuickSettingRow(icon: "externaldrive.fill", title: "settings.storageDataCache".localized) {
                    showSettings = true
                }
                Divider().background(Color.joltBorder).padding(.leading, 52)
                
                QuickSettingRow(icon: "rectangle.portrait.and.arrow.right", title: "settings.logout".localized, isDestructive: true) {
                    showLogoutAlert = true
                }
            }
            .background(Color.joltCardBackground)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("Jolt v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.iosCaption1)
                .foregroundColor(.joltMutedForeground)
            Text("pulse.madeWith".localized)
                .font(.iosCaption1)
                .foregroundColor(.joltMutedForeground)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatReadingTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    private func formatHour(_ hour: Int) -> String {
        return String(format: "%02d:00", hour)
    }
    
    private func repairStreak() {
        withAnimation {
            currentStreak = previousStreak + 1
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
            previousStreak = 0
        }
    }
    
    private func updateLongestStreak() {
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }
    
    private func checkAchievements() {
        _ = AchievementManager.shared.checkAndUnlockAchievements(
            totalJolts: totalJolts,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            collectionsCount: allCollections.count,
            socialJolts: socialJolts,
            articleJolts: articleJolts,
            todayJolts: todayJolts,
            lastJoltHour: lastJoltHour
        )
    }
    
    private func performLogout() {
        Task {
            await AuthService.shared.signOut()
            
            do {
                let bookmarks = try modelContext.fetch(FetchDescriptor<Bookmark>())
                for bookmark in bookmarks { modelContext.delete(bookmark) }
                
                let collections = try modelContext.fetch(FetchDescriptor<Collection>())
                for collection in collections { modelContext.delete(collection) }
                
                let routines = try modelContext.fetch(FetchDescriptor<Routine>())
                for routine in routines { modelContext.delete(routine) }
                
                let syncActions = try modelContext.fetch(FetchDescriptor<SyncAction>())
                for action in syncActions { modelContext.delete(action) }
                
                try modelContext.save()
            } catch {
                print("❌ Failed to clear local data: \(error)")
            }
            
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "notificationPermissionGranted")
            defaults.removeObject(forKey: "lastProcessedClipboardURL")
            defaults.removeObject(forKey: "unlockedAchievements")
            
            currentStreak = 0
            previousStreak = 0
            longestStreak = 0
            lastJoltDateString = ""
            hasCompletedOnboarding = false
            
            if let groupDefaults = UserDefaults(suiteName: "group.com.jolt.shared") {
                groupDefaults.removeObject(forKey: "notificationPermissionGranted")
                groupDefaults.removeObject(forKey: "draft_url")
                groupDefaults.removeObject(forKey: "draft_note")
            }
        }
    }
}

// MARK: - Supporting Views

struct PulseStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                iconColor
                Image(systemName: icon)
                    .font(.iosTitle3)
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .cornerRadius(12)
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.joltForeground)
                
                Text(label)
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.joltCardBackground)
        .cornerRadius(20)
        // MARK: Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(A11y.Pulse.stat(label: label, value: value))
    }
}

struct WeekDayBar: View {
    let date: Date
    let count: Int
    let maxCount: Int
    
    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var barHeight: CGFloat {
        guard maxCount > 0 else { return 8 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(8, ratio * 60)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(count > 0 ? .joltForeground : .joltMutedForeground)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(count > 0 ? Color.joltYellow : Color.joltMuted)
                .frame(height: barHeight)
            
            Text(dayLetter)
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .joltYellow : .joltMutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.joltMuted, lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                if !isUnlocked {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(achievement.color.opacity(0.5), lineWidth: 3)
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                }
                
                Circle()
                    .fill(isUnlocked ? achievement.color : Color.joltMuted)
                    .frame(width: 48, height: 48)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? .white : .joltMutedForeground)
            }
            
            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? .joltForeground : .joltMutedForeground)
                .lineLimit(1)
                .frame(width: 70)
        }
        .opacity(isUnlocked ? 1 : 0.6)
        // MARK: Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(A11y.Pulse.achievement(title: achievement.title, isUnlocked: isUnlocked))
        .accessibilityValue(isUnlocked ? "" : "Yüzde \(Int(progress * 100)) ilerleme")
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.iosBody)
                .foregroundColor(.joltMutedForeground)
                .frame(width: 24)
            
            Text(title)
                .font(.iosBody)
                .foregroundColor(.joltForeground)
            
            Spacer()
            
            Text(value)
                .font(.iosBody)
                .foregroundColor(.joltMutedForeground)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct QuickSettingRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.iosBody)
                    .foregroundColor(isDestructive ? .red : .joltMutedForeground)
                    .frame(width: 24)
                
                Text(title)
                    .font(.iosBody)
                    .foregroundColor(isDestructive ? .red : .joltForeground)
                
                Spacer()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.iosFootnote)
                        .foregroundColor(.joltMutedForeground)
                }
                
                Image(systemName: "chevron.right")
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        // MARK: Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(isDestructive ? A11y.Pulse.logoutHint : "")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Daily Goal Setting Row
struct DailyGoalSettingRow: View {
    @Binding var dailyGoalTarget: Int
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.iosBody)
                .foregroundColor(.joltYellow)
                .frame(width: 24)
            
            Text("settings.dailyGoal".localized)
                .font(.iosBody)
                .foregroundColor(.joltForeground)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if dailyGoalTarget > 1 {
                        dailyGoalTarget -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(dailyGoalTarget > 1 ? .joltMutedForeground : .joltMuted)
                }
                .disabled(dailyGoalTarget <= 1)
                
                Text("\(dailyGoalTarget)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.joltYellow)
                    .frame(minWidth: 30)
                
                Button {
                    if dailyGoalTarget < 10 {
                        dailyGoalTarget += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(dailyGoalTarget < 10 ? .joltYellow : .joltMuted)
                }
                .disabled(dailyGoalTarget >= 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("settings.dailyGoal".localized)
        .accessibilityValue("settings.articlesCount".localized(with: dailyGoalTarget))
    }
}

#Preview {
    PulseView()
        .modelContainer(for: [Bookmark.self, Collection.self, Routine.self], inMemory: true)
}
