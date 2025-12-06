//
//  WatchConnectivityManager.swift
//  JoltWatch Watch App
//
//  Manages communication between Watch and iPhone
//

import Foundation
import WatchConnectivity

// MARK: - Watch Bookmark Model

struct WatchBookmark {
    let title: String
    let domain: String
    let readingTime: Int
}

// MARK: - Connectivity Manager

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var currentStreak: Int = 0
    @Published var todayJolts: Int = 0
    @Published var pendingCount: Int = 0
    @Published var nextBookmark: WatchBookmark?
    @Published var isConnected: Bool = false
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Request Update from iPhone
    
    func requestUpdate() {
        guard let session = session, session.isReachable else {
            print("⌚ iPhone not reachable")
            loadCachedData()
            return
        }
        
        session.sendMessage(["request": "update"], replyHandler: { response in
            DispatchQueue.main.async {
                self.processResponse(response)
            }
        }, errorHandler: { error in
            print("⌚ Error requesting update: \(error)")
            self.loadCachedData()
        })
    }
    
    // MARK: - Process Response
    
    private func processResponse(_ response: [String: Any]) {
        if let streak = response["currentStreak"] as? Int {
            currentStreak = streak
        }
        
        if let today = response["todayJolts"] as? Int {
            todayJolts = today
        }
        
        if let pending = response["pendingCount"] as? Int {
            pendingCount = pending
        }
        
        if let title = response["nextBookmarkTitle"] as? String,
           let domain = response["nextBookmarkDomain"] as? String,
           let time = response["nextBookmarkReadingTime"] as? Int {
            nextBookmark = WatchBookmark(title: title, domain: domain, readingTime: time)
        } else {
            nextBookmark = nil
        }
        
        // Cache data
        cacheData()
    }
    
    // MARK: - Cache Management
    
    private func cacheData() {
        let defaults = UserDefaults.standard
        defaults.set(currentStreak, forKey: "cachedStreak")
        defaults.set(todayJolts, forKey: "cachedTodayJolts")
        defaults.set(pendingCount, forKey: "cachedPendingCount")
        
        if let bookmark = nextBookmark {
            defaults.set(bookmark.title, forKey: "cachedBookmarkTitle")
            defaults.set(bookmark.domain, forKey: "cachedBookmarkDomain")
            defaults.set(bookmark.readingTime, forKey: "cachedBookmarkTime")
        }
    }
    
    private func loadCachedData() {
        let defaults = UserDefaults.standard
        currentStreak = defaults.integer(forKey: "cachedStreak")
        todayJolts = defaults.integer(forKey: "cachedTodayJolts")
        pendingCount = defaults.integer(forKey: "cachedPendingCount")
        
        if let title = defaults.string(forKey: "cachedBookmarkTitle"),
           let domain = defaults.string(forKey: "cachedBookmarkDomain") {
            let time = defaults.integer(forKey: "cachedBookmarkTime")
            nextBookmark = WatchBookmark(title: title, domain: domain, readingTime: time)
        }
    }
}

// MARK: - WCSession Delegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            if self.isConnected {
                self.requestUpdate()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.processResponse(applicationContext)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.processResponse(message)
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
}
