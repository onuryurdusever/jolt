//
//  NetworkMonitor.swift
//  jolt
//
//  Created by Onur Yurdusever on 2.12.2025.
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private var wasOffline = false
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? true
                self?.isOnline = path.status == .satisfied
                
                // If just came back online, trigger sync
                if !wasOnline && self?.isOnline == true {
                    print("🌐 Internet restored! Triggering sync...")
                    NotificationCenter.default.post(name: NSNotification.Name("InternetRestored"), object: nil)
                }
                
                print("🌐 Network status: \(self?.isOnline == true ? "Online ✅" : "Offline ⚠️")")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
