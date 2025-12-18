//
//  WatchConnectivityService.swift
//  jolt
//
//  Manages communication with Apple Watch companion app
//

import Foundation
import WatchConnectivity
import SwiftData
import Combine

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    private var session: WCSession?
    @Published var isWatchPaired: Bool = false
    @Published var isWatchReachable: Bool = false
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Update to Watch
    
    func sendUpdateToWatch(context: ModelContext) {
        guard let session = session, session.isPaired else { return }
        
        // Gather data
        let defaults = UserDefaults(suiteName: "group.com.jolt.shared") ?? .standard
        
        var data: [String: Any] = [
            "currentStreak": UserDefaults.standard.integer(forKey: "currentStreak"),
            "todayJolts": defaults.integer(forKey: "todayJolts"),
            "pendingCount": defaults.integer(forKey: "pendingCount")
        ]
        
        // Next bookmark
        if let title = defaults.string(forKey: "nextBookmarkTitle") {
            data["nextBookmarkTitle"] = title
            data["nextBookmarkDomain"] = defaults.string(forKey: "nextBookmarkDomain") ?? ""
            data["nextBookmarkReadingTime"] = defaults.integer(forKey: "nextBookmarkReadingTime")
        }
        
        // Send via application context (persists until watch reads it)
        do {
            try session.updateApplicationContext(data)
            print("⌚ Sent update to Watch")
        } catch {
            print("⌚ Error sending to Watch: \(error)")
        }
    }
    
    // MARK: - Send Immediate Message
    
    func sendImmediateUpdate(_ data: [String: Any]) {
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage(data, replyHandler: nil) { error in
            print("⌚ Error sending immediate message: \(error)")
        }
    }
}

// MARK: - WCSession Delegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let isPaired = session.isPaired
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isWatchPaired = isPaired
            self.isWatchReachable = isReachable
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Watch is requesting an update
        if message["request"] as? String == "update" {
            let defaults = UserDefaults(suiteName: "group.com.jolt.shared") ?? .standard
            
            var response: [String: Any] = [
                "currentStreak": UserDefaults.standard.integer(forKey: "currentStreak"),
                "todayJolts": defaults.integer(forKey: "todayJolts"),
                "pendingCount": defaults.integer(forKey: "pendingCount")
            ]
            
            if let title = defaults.string(forKey: "nextBookmarkTitle") {
                response["nextBookmarkTitle"] = title
                response["nextBookmarkDomain"] = defaults.string(forKey: "nextBookmarkDomain") ?? ""
                response["nextBookmarkReadingTime"] = defaults.integer(forKey: "nextBookmarkReadingTime")
            }
            
            replyHandler(response)
        }
    }
}
