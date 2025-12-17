//
//  PulseView.swift
//  jolt
//
//  v2.0 - Kontrol Paneli (Command Center)
//  Ferah, dengeli, profesyonel tasarım
//

import SwiftUI
import SwiftData
import WidgetKit
import MessageUI

// MARK: - User Status Tier

enum UserStatusTier {
    case monk       // >= 80%
    case consumer   // 50-79%
    case hoarder    // < 50%
    
    var title: String {
        switch self {
        case .monk: return "pulse.status.monk.title".localized
        case .consumer: return "pulse.status.consumer.title".localized
        case .hoarder: return "pulse.status.hoarder.title".localized
        }
    }
    
    var color: Color {
        switch self {
        case .monk: return .joltYellow
        case .consumer: return .gray
        case .hoarder: return .red
        }
    }
    
    var message: String {
        switch self {
        case .monk: return "pulse.status.monk.message".localized
        case .consumer: return "pulse.status.consumer.message".localized
        case .hoarder: return "pulse.status.hoarder.message".localized
        }
    }
    
    static func from(survivalRate: Int) -> UserStatusTier {
        switch survivalRate {
        case 80...100: return .monk
        case 50..<80: return .consumer
        default: return .hoarder
        }
    }
}

// MARK: - PulseView

struct PulseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allBookmarks: [Bookmark]

    @Query private var allRoutines: [Routine]
    
    // Callback for iPad/Mac sidebar toggle
    var onToggleSidebar: (() -> Void)? = nil
    var isSidebarVisible: Bool = false
    
    struct DeliverySlot: Identifiable {
        let id: Int
    }
    
    @AppStorage("currentStreak") private var currentStreak = 0
    @AppStorage("previousStreak") private var previousStreak = 0
    @AppStorage("longestStreak") private var longestStreak = 0
    @AppStorage("lastJoltDate") private var lastJoltDateString = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("weekendModeEnabled") private var weekendModeEnabled = false
    
    // Sheet States
    @State private var showSettings = false
    @State private var showRoutinesSettings = false
    @State private var showLanguagePicker = false
    @State private var showPremiumView = false
    @State private var showShareSheet = false

    @State private var activeDeliverySlot: DeliverySlot?
    
    // Alert States
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmation = false
    
    // Mail State
    @State private var showMailComposer = false
    
    // UI State for Deletion
    @State private var isProcessingData = false
    
    // MARK: - Computed Properties
    
    private var morningRoutine: Routine? {
        allRoutines.first { $0.icon == "sun.max.fill" }
    }
    
    private var eveningRoutine: Routine? {
        allRoutines.first { $0.icon == "moon.fill" }
    }
    
    private var completedBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .completed }
    }
    
    private var burntBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .expired }
    }
    
    private var survivalRate: Int {
        let completed = completedBookmarks.count
        let burnt = burntBookmarks.count
        let total = completed + burnt
        guard total > 0 else { return 100 }
        return Int((Double(completed) / Double(total)) * 100)
    }
    
    private var userStatus: UserStatusTier {
        UserStatusTier.from(survivalRate: survivalRate)
    }
    
    private var totalReadingTimeMinutes: Int {
        completedBookmarks.reduce(0) { $0 + $1.readingTimeMinutes }
    }
    
    private var archivedBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .archived || $0.status == .completed }
    }
    
    private var totalJolts: Int {
        archivedBookmarks.count
    }
    
    private var topDomains: [(String, Int)] {
        var domainCounts: [String: Int] = [:]
        for bookmark in archivedBookmarks {
            domainCounts[bookmark.domain, default: 0] += 1
        }
        return domainCounts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
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
    
    private var contentMix: [(BookmarkType, Int)] {
        var typeCounts: [BookmarkType: Int] = [:]
        for bookmark in archivedBookmarks {
            typeCounts[bookmark.type, default: 0] += 1
        }
        return typeCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    private var weeklyActivity: [Date: Int] {
        let calendar = Calendar.current
        var activity: [Date: Int] = [:]
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                activity[startOfDay] = 0
            }
        }
        
        for bookmark in archivedBookmarks {
            guard let readAt = bookmark.readAt else { continue }
            let startOfDay = calendar.startOfDay(for: readAt)
            if activity[startOfDay] != nil {
                activity[startOfDay, default: 0] += 1
            }
        }
        
        return activity
    }
    
    private var sortedWeekDays: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -(6 - dayOffset), to: Date())
        }.map { calendar.startOfDay(for: $0) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        if isProcessingData {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            // Header
                            headerSection
                            
                            // Identity Card
                            identityCard
                            
                            // Stats Grid
                            statsGrid
                            
                            // Weekly Activity
                            weeklyActivityCard
                            
                            // Reading Insights
                            insightsCard
                            
                            // Settings Sections
                            settingsSections
                            
                            // Footer
                            footerSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showRoutinesSettings) { NavigationStack { RoutinesSettingsView() } }
            .sheet(isPresented: $showLanguagePicker) { LanguagePickerView() }
            .sheet(isPresented: $showPremiumView) { PremiumView() }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [URL(string: "https://apps.apple.com/app/jolt")!])
            }
            .sheet(isPresented: $showMailComposer) { MailComposerView() }

            .sheet(item: $activeDeliverySlot) { slot in
                DeliveryTimePickerSheet(
                    slot: slot.id,
                    routine: slot.id == 1 ? morningRoutine : eveningRoutine,
                    allBookmarks: allBookmarks,
                    modelContext: modelContext,
                    onDismiss: { activeDeliverySlot = nil }
                )
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
            }
            .alert("alert.logout.title".localized, isPresented: $showLogoutAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("settings.logout".localized, role: .destructive) { performLogout() }
            } message: { Text("alert.logout.message".localized) }
            .alert("settings.deleteAccount".localized, isPresented: $showDeleteAccountAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) { showDeleteConfirmation = true }
            } message: { Text("settings.deleteAccount.warning".localized) }
            .alert("settings.deleteAccount.confirm".localized, isPresented: $showDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("settings.deleteAccount.finalConfirm".localized, role: .destructive) { performDeleteAccount() }
            } message: { Text("settings.deleteAccount.confirmMessage".localized) }
            .onAppear { updateLongestStreak() }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            // Sidebar Toggle (iPad/Mac)
            if let toggle = onToggleSidebar, !isSidebarVisible {
                Button {
                    toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                }
                .padding(.trailing, 12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("pulse.header.title".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.joltMutedForeground)
                    .tracking(3)
                
                Text("pulse.header.subtitle".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Share Button
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.joltYellow)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Identity Card
    
    private var identityCard: some View {
        VStack(spacing: 24) {
            // Status Badge
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(userStatus.color.opacity(0.15))
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .stroke(userStatus.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28))
                        .foregroundColor(userStatus.color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(userStatus.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(userStatus.color)
                        .tracking(1.5)
                    
                    HStack(spacing: 6) {
                        Text("pulse.stats.survivalRate".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("\(survivalRate)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(userStatus.color)
                    }
                    
                    Text(userStatus.message)
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.8))
                        .italic()
                }
                
                Spacer()
            }
            
            // Streak Row
            if currentStreak > 0 {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                        
                        Text("\(currentStreak)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("pulse.stats.streakDays".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if longestStreak > currentStreak {
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow.opacity(0.6))
                            
                            Text("pulse.stats.bestStreak".localized(with: longestStreak))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pulse.section.balance".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(2)
            
            HStack(spacing: 12) {
                StatCard(
                    emoji: "⏱️",
                    value: formatReadingTime(totalReadingTimeMinutes),
                    label: "pulse.section.deepFocus".localized,
                    sublabel: "pulse.section.deepFocus.desc".localized,
                    color: .green
                )
                
                StatCard(
                    emoji: "🔥",
                    value: "\(burntBookmarks.count)",
                    label: "pulse.section.burned".localized,
                    sublabel: "pulse.section.burned.desc".localized,
                    color: .red
                )
                
                StatCard(
                    emoji: "⚡",
                    value: "\(currentStreak)",
                    label: "pulse.section.streak".localized,
                    sublabel: "pulse.section.streak.desc".localized,
                    color: .joltYellow
                )
            }
        }
    }
    
    // MARK: - Weekly Activity
    
    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("pulse.section.thisWeek".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Spacer()
                
                Text("pulse.joltsCount".localized(with: weeklyActivity.values.reduce(0, +)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.joltYellow)
            }
            
            HStack(spacing: 0) {
                ForEach(sortedWeekDays, id: \.self) { date in
                    WeekDayBar(
                        date: date,
                        count: weeklyActivity[date] ?? 0,
                        maxCount: max(weeklyActivity.values.max() ?? 1, 1)
                    )
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Insights Card
    
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pulse.section.habits".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(2)
            
            VStack(spacing: 0) {
                if !topDomains.isEmpty {
                    InsightRow(
                        icon: "globe",
                        title: "pulse.insight.favSources".localized,
                        value: topDomains.map { $0.0 }.joined(separator: ", ")
                    )
                }
                
                if let hour = favoriteReadingHour {
                    InsightRow(
                        icon: "clock",
                        title: "pulse.insight.activeHour".localized,
                        value: formatHour(hour)
                    )
                }
                
                InsightRow(
                    icon: "timer",
                    title: "pulse.insight.avgRead".localized,
                    value: String(format: "%.0f dakika", averageReadingTime)
                )
                
                if !contentMix.isEmpty {
                    InsightRow(
                        icon: "chart.pie",
                        title: "pulse.insight.contentType".localized,
                        value: contentMix.prefix(2).map { $0.0.rawValue.capitalized }.joined(separator: ", "),
                        isLast: true
                    )
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Settings Sections
    
    private var settingsSections: some View {
        VStack(spacing: 24) {
            // Doz Sistemi - v2.1 Yeni Tasarım
            SettingsBlock(title: "DOZ SİSTEMİ") {
                // Sabah Dozu - Her zaman göster
                DeliveryTimeRow(
                    slotNumber: 1,
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "pulse.settings.morningDose".localized,
                    time: morningRoutine?.timeString ?? "08:30",
                    isEnabled: morningRoutine?.isEnabled ?? false
                ) {
                    ensureMorningRoutineExists()
                    activeDeliverySlot = DeliverySlot(id: 1)
                }
                
                // Akşam Dozu - Her zaman göster
                DeliveryTimeRow(
                    slotNumber: 2,
                    icon: "moon.fill",
                    iconColor: .purple,
                    title: "pulse.settings.eveningDose".localized,
                    time: eveningRoutine?.timeString ?? "21:00",
                    isEnabled: eveningRoutine?.isEnabled ?? false
                ) {
                    ensureEveningRoutineExists()
                    activeDeliverySlot = DeliverySlot(id: 2)
                }
                
                // Hafta Sonu Modu
                WeekendModeRow(isEnabled: $weekendModeEnabled)
            }
            
            // Sistem
            SettingsBlock(title: "SİSTEM") {
                SettingsRow(icon: "globe", title: "pulse.settings.language".localized, value: LanguageManager.shared.currentLanguage.displayName) {
                    showLanguagePicker = true
                }
                SettingsRow(icon: "bell.fill", title: "settings.notifications".localized, isLast: true) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            
            // Veri
            SettingsBlock(title: "VERİ") {
                SettingsRow(icon: "square.and.arrow.up", title: "pulse.settings.export".localized, value: "JSON") {
                    showSettings = true
                }
                SettingsRow(icon: "trash", title: "pulse.settings.clearCache".localized, isLast: true) {
                    showSettings = true
                }
            }
            
            // Abonelik
            SettingsBlock(title: "ABONELİK") {
                SettingsRow(
                    icon: "bolt.fill",
                    title: "premium.title".localized,
                    value: StoreManager.shared.isPremium ? "PRO ⚡" : "FREE",
                    iconColor: .joltYellow
                ) {
                    showPremiumView = true
                }
                SettingsRow(icon: "arrow.clockwise", title: "pulse.settings.restore".localized, isLast: true) {
                    Task { await StoreManager.shared.restorePurchases() }
                }
            }
            
            // Danger Zone
            SettingsBlock(title: "HESAP", isDanger: true) {
                SettingsRow(icon: "envelope.fill", title: "pulse.settings.support".localized) {
                    showMailComposer = true
                }
                SettingsRow(icon: "hand.raised.fill", title: "pulse.settings.privacy".localized) {
                    if let url = URL(string: "https://jolt.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                SettingsRow(icon: "doc.text.fill", title: "pulse.settings.terms".localized) {
                    if let url = URL(string: "https://jolt.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "pulse.settings.logout".localized, isDestructive: true) {
                    showLogoutAlert = true
                }
                SettingsRow(icon: "person.crop.circle.badge.xmark", title: "pulse.settings.deleteAccount".localized, isDestructive: true, isLast: true) {
                    showDeleteAccountAlert = true
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Jolt v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("pulse.madeWith".localized)
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helpers
    
    private func formatReadingTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)s \(mins)d" : "\(hours)s"
        }
        return "\(minutes)d"
    }
    
    private func formatHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
    
    private func updateLongestStreak() {
        if currentStreak > longestStreak { longestStreak = currentStreak }
    }
    
    private func performLogout() {
        isProcessingData = true
        Task {
            // Wait a bit to let UI update
            try? await Task.sleep(nanoseconds: 200_000_000)
            await AuthService.shared.signOut()
            await clearLocalData()
            isProcessingData = false
        }
    }
    
    private func performDeleteAccount() {
        isProcessingData = true
        Task {
            // Wait a bit to let UI update
            try? await Task.sleep(nanoseconds: 200_000_000)
            await AuthService.shared.deleteAccount()
            await clearLocalData()
            isProcessingData = false
        }
    }
    
    @MainActor
    private func clearLocalData() async {
        do {
            let bookmarks = try modelContext.fetch(FetchDescriptor<Bookmark>())
            for bookmark in bookmarks { modelContext.delete(bookmark) }
            

            
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
        
        UserDefaults.standard.removeObject(forKey: "notificationPermissionGranted")
        UserDefaults.standard.removeObject(forKey: "lastProcessedClipboardURL")
        
        // Tutorial kartlarını resetle - yeni hesapta tekrar oluşsunlar
        UserDefaults.standard.removeObject(forKey: "tutorialCardsCreated")
        
        currentStreak = 0
        previousStreak = 0
        longestStreak = 0
        lastJoltDateString = ""
        hasCompletedOnboarding = false
        
        UserDefaults(suiteName: "group.com.jolt.shared")?.removeObject(forKey: "notificationPermissionGranted")
        UserDefaults(suiteName: "group.com.jolt.shared")?.removeObject(forKey: "draft_url")
        UserDefaults(suiteName: "group.com.jolt.shared")?.removeObject(forKey: "draft_note")
    }
    
    // MARK: - Ensure Routines Exist
    
    private func ensureMorningRoutineExists() {
        guard morningRoutine == nil else { return }
        let routine = Routine(
            name: "delivery.morning".localized,
            icon: "sun.max.fill",
            hour: 8,
            minute: 30,
            days: [2, 3, 4, 5, 6], // Mon-Fri
            isEnabled: true
        )
        modelContext.insert(routine)
        try? modelContext.save()
    }
    
    private func ensureEveningRoutineExists() {
        guard eveningRoutine == nil else { return }
        let routine = Routine(
            name: "delivery.evening".localized,
            icon: "moon.fill",
            hour: 21,
            minute: 0,
            days: [1, 2, 3, 4, 5, 6, 7], // Daily
            isEnabled: true
        )
        modelContext.insert(routine)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let emoji: String
    let value: String
    let label: String
    let sublabel: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(emoji)
                .font(.system(size: 28))
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text(sublabel)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct WeekDayBar: View {
    let date: Date
    let count: Int
    let maxCount: Int
    
    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(2))
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var barHeight: CGFloat {
        guard maxCount > 0 else { return 6 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(6, ratio * 50)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(count > 0 ? .white : .gray.opacity(0.5))
            
            RoundedRectangle(cornerRadius: 3)
                .fill(count > 0 ? Color.joltYellow : Color.white.opacity(0.08))
                .frame(width: 24, height: barHeight)
            
            Text(dayLetter)
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .joltYellow : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.leading, 60)
            }
        }
    }
}

struct SettingsBlock<Content: View>: View {
    let title: String
    var isDanger: Bool = false
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isDanger ? .red.opacity(0.8) : .gray)
                .tracking(2)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var iconColor: Color = .gray
    var isDestructive: Bool = false
    var isLast: Bool = false
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isDestructive ? .red : iconColor)
                        .frame(width: 28)
                    
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(isDestructive ? .red : .white)
                    
                    Spacer()
                    
                    if let value = value {
                        Text(value)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.leading, 60)
            }
        }
    }
}

// MARK: - Delivery Time Row (v2.1)

struct DeliveryTimeRow: View {
    let slotNumber: Int
    let icon: String
    let iconColor: Color
    let title: String
    let time: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isEnabled ? iconColor : .gray)
                }
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isEnabled ? .white : .gray)
                
                Spacer()
                
                if isEnabled {
                    Text(time)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.joltYellow)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 66)
    }
}

// MARK: - Weekend Mode Row (v2.1)

struct WeekendModeRow: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isEnabled ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("pulse.weekendMode".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Text("pulse.weekendMode.desc".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(.joltYellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Delivery Time Picker Sheet (v2.1)

struct DeliveryTimePickerSheet: View {
    let slot: Int
    let routine: Routine?
    let allBookmarks: [Bookmark]
    let modelContext: ModelContext
    let onDismiss: () -> Void
    
    @State private var selectedTime: Date = Date()
    @State private var isEnabled: Bool = true
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var showRescheduleWarning = false
    
    private var title: String {
        slot == 1 ? "Sabah Dozu" : "Akşam Dozu"
    }
    
    private var iconColor: Color {
        slot == 1 ? .orange : .purple
    }
    
    private var icon: String {
        slot == 1 ? "sun.max.fill" : "moon.fill"
    }
    
    // Etkilenecek bekleyen içerik sayısı
    private var pendingBookmarksCount: Int {
        guard let routine = routine else { return 0 }
        let oldHour = routine.hour
        let oldMinute = routine.minute
        
        return allBookmarks.filter { bookmark in
            guard bookmark.status == .active else { return false }
            let calendar = Calendar.current
            let scheduledHour = calendar.component(.hour, from: bookmark.scheduledFor)
            let scheduledMinute = calendar.component(.minute, from: bookmark.scheduledFor)
            return scheduledHour == oldHour && scheduledMinute == oldMinute
        }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Icon & Title
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(iconColor)
                    }
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Time Picker
                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(height: 150)
                
                // Day Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Günler")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        ForEach([1, 2, 3, 4, 5, 6, 7], id: \.self) { day in
                            DayPillButton(day: day, isSelected: selectedDays.contains(day)) {
                                if selectedDays.contains(day) {
                                    if selectedDays.count > 1 { selectedDays.remove(day) }
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Enable/Disable Toggle
                HStack {
                    Text("pulse.delivery.enabled".localized)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(.joltYellow)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                // Reschedule Warning
                if pendingBookmarksCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13))
                        Text("pulse.delivery.reschedule".localized(with: pendingBookmarksCount))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.joltYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.joltYellow.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        onDismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveChanges()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.joltYellow)
                }
            }
        }
        .onAppear {
            if let routine = routine {
                let calendar = Calendar.current
                selectedTime = calendar.date(from: DateComponents(hour: routine.hour, minute: routine.minute)) ?? Date()
                isEnabled = routine.isEnabled
                selectedDays = Set(routine.days)
            }
        }
    }
    
    private func saveChanges() {
        guard let routine = routine else { return }
        
        let calendar = Calendar.current
        let oldHour = routine.hour
        let oldMinute = routine.minute
        let newHour = calendar.component(.hour, from: selectedTime)
        let newMinute = calendar.component(.minute, from: selectedTime)
        
        // Routine'u güncelle
        routine.hour = newHour
        routine.minute = newMinute
        routine.isEnabled = isEnabled
        routine.days = Array(selectedDays).sorted()
        
        // Reschedule: Mevcut kuyruktaki içerikleri yeni saate taşı
        if oldHour != newHour || oldMinute != newMinute {
            rescheduleBookmarks(oldHour: oldHour, oldMinute: oldMinute, newHour: newHour, newMinute: newMinute)
        }
        
        try? modelContext.save()
        
        // Bildirimleri yeniden planla via centralized observer
        NotificationCenter.default.post(name: .routinesDidChange, object: nil)
    }
    
    private func rescheduleBookmarks(oldHour: Int, oldMinute: Int, newHour: Int, newMinute: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        for bookmark in allBookmarks {
            guard bookmark.status == .active else { continue }
            
            let scheduledHour = calendar.component(.hour, from: bookmark.scheduledFor)
            let scheduledMinute = calendar.component(.minute, from: bookmark.scheduledFor)
            
            // Eski saatte planlanmış içerikleri bul
            guard scheduledHour == oldHour && scheduledMinute == oldMinute else { continue }
            
            // Yeni tarihi hesapla
            var newComponents = calendar.dateComponents([.year, .month, .day], from: bookmark.scheduledFor)
            newComponents.hour = newHour
            newComponents.minute = newMinute
            
            guard var newDate = calendar.date(from: newComponents) else { continue }
            
            // Eğer yeni saat bugün için zaten geçtiyse, yarına at
            if newDate <= now {
                newDate = calendar.date(byAdding: .day, value: 1, to: newDate) ?? newDate
            }
            
            bookmark.scheduledFor = newDate
        }
    }
}

// MARK: - Day Pill Button

struct DayPillButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    private var dayLabel: String {
        let labels = ["Pz", "Pt", "Sa", "Ça", "Pe", "Cu", "Ct"]
        return labels[day - 1]
    }
    
    var body: some View {
        Button(action: action) {
            Text(dayLabel)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.joltYellow : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(["support@jolt.app"])
        vc.setSubject("Jolt Destek")
        vc.setMessageBody("Jolt v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")\n\n", isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        init(_ parent: MailComposerView) { self.parent = parent }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    PulseView()
        .modelContainer(for: [Bookmark.self, Routine.self], inMemory: true)
}
