//
//  StartupManager.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//
//  Determinisitc Startup Orchestrator
//  Ensures <200ms TTFP by deferring all non-UI work.
//

import SwiftUI
import SwiftData
import AVFoundation

@MainActor
class StartupManager {
    static let shared = StartupManager()
    
    // State to ensure single execution
    private var hasStarted = false
    
    // Configuration
    private let authDelay: UInt64 = 500_000_000 // 0.5s
    private let audioDelay: UInt64 = 2_000_000_000 // 2.0s
    private let enrichmentDelay: UInt64 = 5_000_000_000 // 5.0s (Aggressive but safe)
    
    private init() {}
    
    /// Called when ContentView appears (First Paint)
    func onFirstPaint(context: ModelContext) {
        guard !hasStarted else { return }
        hasStarted = true
        
        print("🎨 First Paint Confirmed. StartupManager taking control.")
        
        // 1. Critical Background Services (Auth)
        Task {
            try? await Task.sleep(nanoseconds: authDelay)
            print("🔐 Startup: Initializing Auth...")
            await AuthService.shared.initializeAnonymousSession()
        }
        
        // 2. Heavy System Resources (Audio)
        Task {
            try? await Task.sleep(nanoseconds: audioDelay)
            print("🔊 Startup: Configuring Audio...")
            setupAudioSession()
        }
        
        // 3. Data Enrichment (Network Heavy)
        Task {
            try? await Task.sleep(nanoseconds: enrichmentDelay)
            if NetworkMonitor.shared.isOnline {
                print("🌍 Startup: Triggering Enrichment...")
                await EnrichmentService.shared.processPendingEnrichments(context: context)
            } else {
                print("🌍 Startup: Offline, skipping enrichment.")
            }
        }
        
        // 4. Update Widgets (Low Priority)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            print("📱 Startup: Updating Widgets...")
            WidgetDataService.shared.updateWidgetData(modelContext: context)
        }
    }
    
    /// Centralized ScenePhase handler
    func onScenePhaseChanged(_ phase: ScenePhase, context: ModelContext) {
        switch phase {
        case .active:
            print("📱 App Active")
            // Schedule streak protection
            NotificationManager.shared.scheduleStreakProtectionNotification(modelContext: context)
            NotificationManager.shared.updateBadgeCount(modelContext: context)
            
            // Trigger auto-sync if we are already started (warm resume)
            if hasStarted {
                Task {
                    // Slight delay to let UI settle
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if NetworkMonitor.shared.isOnline {
                        await EnrichmentService.shared.processPendingEnrichments(context: context)
                    }
                    WidgetDataService.shared.updateWidgetData(modelContext: context)
                }
            }
            
        case .background:
            print("📱 App Background")
            WidgetDataService.shared.updateWidgetData(modelContext: context)
            NotificationManager.shared.updateBadgeCount(modelContext: context)
            
        case .inactive:
            break
            
        @unknown default:
            break
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
    }
}
