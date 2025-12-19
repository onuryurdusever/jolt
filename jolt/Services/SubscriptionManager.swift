//
//  SubscriptionManager.swift
//  jolt
//
//  Created by Antigravity on 18.12.2025.
//

import SwiftUI
import RevenueCat
import RevenueCatUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var isPurchasing: Bool = false
    
    private init() {
        // Shared container initialized with default state
        // Actual status will be fetched on configure
    }
    
    /// SDK Başlatma
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_MUmIDEFGpCEadXnYTJTnFnDCAgE") // Sandbox Key
        Purchases.shared.delegate = PurchasesDelegateHandler.shared
        
        Task {
            await updateStatus()
            await fetchOfferings()
        }
    }
    
    /// Abonelik durumunu güncelle
    func updateStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateProStatus(customerInfo)
            
            #if DEBUG
            print("💎 Pro Status: \(isPro)")
            #endif
        } catch {
            print("❌ RevenueCat: Failed to fetch customer info: \(error.localizedDescription)")
        }
    }
    
    func updateProStatus(_ customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements["Jolt Pro"]?.isActive ?? false
        self.isPro = active
        
        // Save to Shared App Group for Widgets and Extensions
        if let sharedDefaults = UserDefaults(suiteName: "group.com.jolt.shared") {
            sharedDefaults.set(active, forKey: "is_pro")
            // Also keep isPremium for compatibility during migration if needed, 
            // but we'll move everything to is_pro
            sharedDefaults.set(active, forKey: "isPremium")
        }
    }

    /// Teklifleri (Offerings) getir
    func fetchOfferings() async {
        do {
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            print("❌ RevenueCat: Failed to fetch offerings: \(error.localizedDescription)")
        }
    }
    
    /// Satın alma işlemi
    func purchase(package: Package) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                updateProStatus(result.customerInfo)
                return isPro
            }
            return false
        } catch {
            print("❌ RevenueCat: Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Satın alma geri yükleme (Restore)
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateProStatus(customerInfo)
        } catch {
            print("❌ RevenueCat: Restore failed: \(error.localizedDescription)")
        }
    }
}

/// RevenueCat delegate olaylarını yakalayan yardımcı sınıf
class PurchasesDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchasesDelegateHandler()
    
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionManager.shared.updateProStatus(customerInfo)
        }
    }
}
