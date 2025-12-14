//
//  PremiumView.swift
//  jolt
//
//  v2.1 - Premium subscription with StoreKit 2
//

import SwiftUI
import StoreKit
import Combine

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreManager.shared
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    heroSection
                        .padding(.top, 20)
                    
                    // Features
                    featuresSection
                        .padding(.horizontal, 20)
                    
                    // Pricing
                    pricingSection
                        .padding(.horizontal, 20)
                    
                    // Purchase Button
                    purchaseButton
                        .padding(.horizontal, 20)
                    
                    // Restore & Terms
                    footerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.joltBackground.ignoresSafeArea())
            .navigationTitle("premium.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("common.error".localized, isPresented: $showError) {
                Button("common.done".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await storeManager.loadProducts()
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Pro Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.black)
            }
            
            Text("premium.title".localized)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("premium.subtitle".localized)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            PremiumFeatureRow(
                icon: "clock.fill",
                iconColor: .yellow,
                title: "premium.feature.14days".localized,
                subtitle: "premium.features.time.subtitle".localized
            )
            
            PremiumFeatureRow(
                icon: "arrow.clockwise.circle.fill",
                iconColor: .orange,
                title: "premium.feature.unlimitedSnooze".localized,
                subtitle: "premium.features.snooze.subtitle".localized
            )
            

            
            PremiumFeatureRow(
                icon: "chart.bar.fill",
                iconColor: .green,
                title: "premium.feature.stats".localized,
                subtitle: "premium.features.stats.subtitle".localized
            )
            
            PremiumFeatureRow(
                icon: "rectangle.stack.fill",
                iconColor: .purple,
                title: "premium.feature.widgets".localized,
                subtitle: "premium.features.widgets.subtitle".localized
            )
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(storeManager.products) { product in
                PricingOption(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isBestValue: product.id == "jolt.pro.yearly"
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = product
                    }
                }
            }
        }
        .onAppear {
            // Default select yearly
            if selectedProduct == nil {
                selectedProduct = storeManager.products.first { $0.id == "jolt.pro.yearly" }
                    ?? storeManager.products.first
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("premium.cta".localized)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await storeManager.restorePurchases()
                }
            } label: {
                Text("premium.restore".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Text("premium.footer.terms".localized)
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    // MARK: - Actions
    
    private func purchase() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let success = try await storeManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Premium Feature Row

struct PremiumFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Pricing Option

struct PricingOption: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if isBestValue {
                            Text("premium.pricing.bestValue".localized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let period = formatPeriod(product) {
                        Text(period)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .yellow : .white)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .yellow : .gray)
            }
            .padding(16)
            .background(isSelected ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func formatPeriod(_ product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "premium.pricing.monthly".localized
        case .year:
            return "premium.pricing.yearly".localized
        default:
            return nil
        }
    }
}

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isPremium: Bool = false
    
    private let productIDs = [
        "jolt.pro.monthly",
        "jolt.pro.yearly",
        "jolt.pro.lifetime"
    ]
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = listenForTransactions()
        
        Task {
            await updatePurchasedProducts()
        }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { product1, product2 in
                    // Sort: monthly, yearly, lifetime
                    let order = ["jolt.pro.monthly", "jolt.pro.yearly", "jolt.pro.lifetime"]
                    let index1 = order.firstIndex(of: product1.id) ?? 99
                    let index2 = order.firstIndex(of: product2.id) ?? 99
                    return index1 < index2
                }
        } catch {
            print("❌ Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("❌ Restore failed: \(error)")
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            purchased.insert(transaction.productID)
        }
        
        purchasedProductIDs = purchased
        isPremium = !purchased.isEmpty
        
        // Save to UserDefaults for widget/extension access
        UserDefaults.standard.set(isPremium, forKey: "isPremium")
        UserDefaults(suiteName: "group.com.jolt.shared")?.set(isPremium, forKey: "isPremium")
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }
}

enum StoreError: Error {
    case verificationFailed
}

// MARK: - Preview

#Preview {
    PremiumView()
}
