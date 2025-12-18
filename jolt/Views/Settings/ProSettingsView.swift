//
//  ProSettingsView.swift
//  jolt
//
//  Created by Antigravity on 18.12.2025.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct ProSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var config = ConfigManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    
    @State private var tempDays: Int = 7
    @State private var showingConfirmation = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("expire.duration".localized)
                            .font(.headline)
                        Spacer()
                        Text("\(tempDays) \("time.days".localized)")
                            .foregroundColor(.joltGreen)
                            .font(.title3.bold())
                    }
                    
                    Slider(value: Binding(get: {
                        Double(tempDays)
                    }, set: {
                        tempDays = Int($0)
                    }), in: 7...30, step: 1)
                    .accentColor(.joltGreen)
                    
                    Text("settings.pro.durationHint".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            } header: {
                Text("settings.pro.customExpiration".localized)
            } footer: {
                Text("settings.pro.philosophyHint".localized)
            }
            
            Section {
                Button {
                    saveChanges()
                } label: {
                    HStack {
                        Spacer()
                        Text("common.save".localized)
                            .bold()
                        Spacer()
                    }
                }
                .foregroundColor(.joltGreen)
            }
        }
        .navigationTitle("settings.pro.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tempDays = config.expireDays
        }
        .alert("alert.pro.updatePending.title".localized, isPresented: $showingConfirmation) {
            Button("common.no".localized, role: .cancel) {
                dismiss()
            }
            Button("common.yes".localized) {
                updatePendingBookmarks()
            }
        } message: {
            Text("alert.pro.updatePending.message".localized)
        }
    }
    
    private func saveChanges() {
        let oldDays = config.expireDays
        config.updateExpireDays(tempDays)
        
        if tempDays != oldDays {
            showingConfirmation = true
        } else {
            dismiss()
        }
    }
    
    private func updatePendingBookmarks() {
        ExpirationService.shared.bulkUpdateExpiration(
            modelContext: modelContext,
            newDays: tempDays,
            isPro: subManager.isPro
        )
        dismiss()
    }
}
