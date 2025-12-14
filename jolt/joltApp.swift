//
//  joltApp.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData
import AVFoundation

@main
struct joltApp: App {
    @StateObject private var authService = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bookmark.self,
            SyncAction.self,
            Routine.self,
        ])
        
        // Configure with App Group container
        guard let appGroupURL = AppGroup.containerURL else {
            fatalError("Could not get App Group container URL")
        }
        
        let modelConfiguration = ModelConfiguration(
            url: appGroupURL.appendingPathComponent("jolt.sqlite")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Configure Audio Session to mix with others (Spotify, Apple Music)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
        
        // Initialize auth on app launch
        Task {
            await AuthService.shared.initializeAnonymousSession()
        }
        
        // Note: Notification permission is requested during onboarding
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            let context = sharedModelContainer.mainContext
            
            switch newPhase {
            case .background:
                // Update badge when going to background
                NotificationManager.shared.updateBadgeCount(modelContext: context)
                
            case .active:
                // Schedule streak protection when app becomes active
                NotificationManager.shared.scheduleStreakProtectionNotification(modelContext: context)
                // Also update badge on foreground
                NotificationManager.shared.updateBadgeCount(modelContext: context)
                
            case .inactive:
                break
                
            @unknown default:
                break
            }
        }
    }
}
