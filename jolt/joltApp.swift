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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bookmark.self,
            Collection.self,
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
    }
}
