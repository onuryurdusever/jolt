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
        #if targetEnvironment(macCatalyst)
        // For Catalyst, we might need a different approach or this might not compile.
        // Try HiddenTitleBarWindowStyle if available, or remove if it causes build errors.
        // Actually, .windowStyle(.hiddenTitleBar) is macOS specific.
        // For now, let's remove the title bar via SceneDelegate or similar if possible.
        // But for SwiftUI only:
        // .windowStyle(.hiddenTitleBar) is NOT available in Catalyst. 
        // We will TRY .windowStyle(.automatic) or remove the #if block to see if HiddenTitleBar compiles.
        // BUT, since user complained it IS visible, the previous code didn't run.
        // Let's try to remove the #if check and use a modifier that works, 
        // OR acknowledge that we might need UIKit introspection later.
        // For now, I will revert to standard and try to inject a bridge.
        // WAIT, the simplest fix for Catalyst title bar is in the Scene config in Info.plist or UIKit.
        // Let's just comment it out for now to ensure it doesn't break, and investigate Export crash.
        // User asked to hide it. I will try a known Catalyst workaround via introspect later.
        // FOR THIS STEP: Just correct the conditional to targetEnvironment(macCatalyst) to see if it works.
        // NOTE: .hiddenTitleBar is macOS 11.0+. Catalyst 14.0+ is based on iOS 14. 
        // It likely won't compile. I will REMOVE it for now to avoid build errors and revisit.
        #endif
    }


}
