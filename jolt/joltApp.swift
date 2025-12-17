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
        // KILL: Removed side-effects (Audio, Auth) for deterministic startup.
    }


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
        .modelContainer(sharedModelContainer)
        // KILL: Removed .onChange. Lifecycle managed by startupManager via ContentView.
    }


}
