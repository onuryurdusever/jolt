//
//  OnboardingView.swift
//  jolt
//
//  v2.1 - Final Onboarding Flow
//  DOZ sistemi: Dijital Obeziteye Karşı Detoks
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.modelContext) private var modelContext
    
    // State
    @State private var currentStep: Int = 1
    @State private var morningDeliveryEnabled = true
    @State private var eveningDeliveryEnabled = true
    @State private var morningTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date()
    @State private var eveningTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    
    private let totalSteps = 5
    
    var body: some View {
        ZStack {
            Color.joltBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar (hidden on first screen)
                if currentStep > 1 {
                    ProgressBar(current: currentStep, total: totalSteps)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }
                
                // Content
                TabView(selection: $currentStep) {
                    // EKRAN 1: YÜZLEŞME (The Wake Up Call)
                    WakeUpCallView(onNext: nextStep)
                        .tag(1)
                    
                    // EKRAN 2: KURAL (The Law)
                    TheLawView(onNext: nextStep)
                        .tag(2)
                    
                    // EKRAN 3: MEKANİK (The How-To)
                    HowToView(onNext: nextStep)
                        .tag(3)
                    
                    // EKRAN 4: TESLİMAT (The Delivery)
                    DeliveryView(
                        morningEnabled: $morningDeliveryEnabled,
                        eveningEnabled: $eveningDeliveryEnabled,
                        morningTime: $morningTime,
                        eveningTime: $eveningTime,
                        onNext: nextStep
                    )
                    .tag(4)
                    
                    // EKRAN 5: GÜVENLİ GİRİŞ (Training Mode)
                    TrainingModeView(onFinish: completeOnboarding)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }
    
    private func completeOnboarding() {
        let calendar = Calendar.current
        
        // 1. Create Delivery Slots (eski Routine yerine)
        let morningHour = calendar.component(.hour, from: morningTime)
        let morningMinute = calendar.component(.minute, from: morningTime)
        let eveningHour = calendar.component(.hour, from: eveningTime)
        let eveningMinute = calendar.component(.minute, from: eveningTime)
        
        // Morning Delivery (Mon-Fri)
        if morningDeliveryEnabled {
            let morningSlot = Routine(
                name: "delivery.morning".localized,
                icon: "sun.max.fill",
                hour: morningHour,
                minute: morningMinute,
                days: [2, 3, 4, 5, 6], // Mon-Fri
                isEnabled: true
            )
            modelContext.insert(morningSlot)
        }
        
        // Evening Delivery (Daily)
        if eveningDeliveryEnabled {
            let eveningSlot = Routine(
                name: "delivery.evening".localized,
                icon: "moon.fill",
                hour: eveningHour,
                minute: eveningMinute,
                days: [1, 2, 3, 4, 5, 6, 7],
                isEnabled: true
            )
            modelContext.insert(eveningSlot)
        }
        
        // 2. Save Context
        try? modelContext.save()
        
        // 3. Create Tutorial Cards for Focus
        let userID = AuthService.shared.currentUserID ?? "anonymous"
        OnboardingTutorialService.shared.createTutorialCards(modelContext: modelContext, userID: userID)
        
        // 4. Schedule Initial Notifications via centralized observer
        NotificationCenter.default.post(name: .routinesDidChange, object: nil)
        
        // 5. Start Training Mode (3 gün dokunulmazlık)
        ExpirationService.shared.startTrainingMode()
        
        // 6. Finish
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.joltYellow : Color.white.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - EKRAN 1: YÜZLEŞME (The Wake Up Call)

struct WakeUpCallView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    @State private var linkCount = 0
    @State private var tabCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Mezar Taşı İkonu
                VStack(spacing: 24) {
                    Text("🪦")
                        .font(.system(size: 100))
                        .opacity(animationStep >= 1 ? 1 : 0)
                        .scaleEffect(animationStep >= 1 ? 1 : 0.5)
                    
                    // Canlı Sayaçlar
                    HStack(spacing: 32) {
                        CounterView(
                            count: linkCount,
                            label: "onboarding.wakeup.links".localized,
                            isVisible: animationStep >= 2
                        )
                        
                        CounterView(
                            count: tabCount,
                            label: "onboarding.wakeup.tabs".localized,
                            isVisible: animationStep >= 2
                        )
                    }
                }
                
                // Başlık
                VStack(spacing: 16) {
                    Text("onboarding.wakeup.title".localized)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(animationStep >= 3 ? 1 : 0)
                    
                    Text("onboarding.wakeup.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .opacity(animationStep >= 3 ? 1 : 0)
                }
            }
            
            Spacer()
            
            // Ana Buton
            Button(action: onNext) {
                Text("onboarding.wakeup.button".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .opacity(animationStep >= 3 ? 1 : 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Staggered animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                animationStep = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                animationStep = 2
            }
            
            // Animate counters
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 1.5)) {
                    linkCount = 312
                    tabCount = 47
                }
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(1.8)) {
                animationStep = 3
            }
        }
    }
}

struct CounterView: View {
    let count: Int
    let label: String
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .opacity(isVisible ? 1 : 0)
    }
}

// MARK: - EKRAN 2: KURAL (The Law)

struct TheLawView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    @State private var sandAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Kum Saati Animasyonu
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.joltYellow.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .opacity(sandAnimating ? 0.8 : 0.3)
                    
                    Text("⏳")
                        .font(.system(size: 100))
                        .rotationEffect(.degrees(sandAnimating ? 5 : -5))
                }
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: sandAnimating)
                
                // Başlık
                VStack(spacing: 16) {
                    Text("onboarding.law.title".localized)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                        .opacity(animationStep >= 1 ? 1 : 0)
                    
                    Text("onboarding.law.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .opacity(animationStep >= 2 ? 1 : 0)
                    
                    // 7 Gün Badge
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 18))
                        Text("onboarding.law.sevenDays".localized)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.joltYellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.joltYellow.opacity(0.15))
                    .cornerRadius(12)
                    .opacity(animationStep >= 3 ? 1 : 0)
                    .scaleEffect(animationStep >= 3 ? 1 : 0.8)
                }
                
                // Küçük Not
                Text("onboarding.law.note".localized)
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.8))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animationStep >= 4 ? 1 : 0)
            }
            
            Spacer()
            
            // Ana Buton
            Button(action: onNext) {
                Text("onboarding.law.button".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .opacity(animationStep >= 4 ? 1 : 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            sandAnimating = true
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { animationStep = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { animationStep = 2 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.2)) { animationStep = 3 }
            withAnimation(.easeOut(duration: 0.5).delay(1.8)) { animationStep = 4 }
        }
    }
}

// MARK: - EKRAN 3: MEKANİK (The How-To)

/// Onboarding için basitleştirilmiş seçenek tipi
enum OnboardingOption: String, CaseIterable {
    case morning
    case evening
    case weekend
    
    var displayName: String {
        switch self {
        case .morning: return "intent.morning".localized
        case .evening: return "intent.evening".localized
        case .weekend: return "intent.weekend".localized
        }
    }
    
    var subtitle: String {
        switch self {
        case .morning: return "intent.morning.subtitle".localized
        case .evening: return "intent.evening.subtitle".localized
        case .weekend: return "intent.weekend.subtitle".localized
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .evening: return "moon.fill"
        case .weekend: return "calendar"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .morning: return .orange
        case .evening: return .purple
        case .weekend: return .blue
        }
    }
}

struct HowToView: View {
    let onNext: () -> Void
    @State private var selectedOption: OnboardingOption? = nil
    @State private var showShareSheet = false
    @State private var demoStep = 0
    
    private var canContinue: Bool {
        selectedOption != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.howto.title".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("onboarding.howto.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Demo Phone
            ZStack {
                // Phone Frame
                RoundedRectangle(cornerRadius: 36)
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 300, height: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color.black)
                    )
                
                VStack(spacing: 0) {
                    // Safari-like header
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 32)
                            .overlay(
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                    Text("medium.com/article...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    
                    // Content placeholder
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 180, height: 12)
                    }
                    .padding(16)
                    
                    Spacer()
                    
                    // Share Sheet
                    if showShareSheet {
                        VStack(spacing: 16) {
                            // Header
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.joltYellow)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.black)
                                            .font(.system(size: 20))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("How to Build a Second Brain")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("medium.com")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            
                            // Soru
                            Text("onboarding.howto.question".localized)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // 3 Basit Seçenek: Sabah, Akşam, Hafta Sonu
                            VStack(spacing: 8) {
                                ForEach(OnboardingOption.allCases, id: \.self) { option in
                                    OnboardingOptionButton(
                                        option: option,
                                        isSelected: selectedOption == option,
                                        action: { withAnimation { selectedOption = option } }
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(hex: "#1C1C1E"))
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Share Icon (before sheet appears)
                    if demoStep == 1 && !showShareSheet {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 44))
                            .foregroundColor(.joltYellow)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 300, height: 400)
            }
            
            Spacer()
            
            // Ana Buton
            Button(action: onNext) {
                Text("onboarding.howto.button".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(canContinue ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? Color.joltYellow : Color.white.opacity(0.1))
                    .cornerRadius(16)
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Animation sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    demoStep = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showShareSheet = true
                }
            }
        }
    }
}

struct OnboardingOptionButton: View {
    let option: OnboardingOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .black : option.iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
                .foregroundColor(isSelected ? .black : .white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                }
            }
            .padding(14)
            .background(isSelected ? Color.joltYellow : Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EKRAN 4: TESLİMAT (The Delivery) - v2.1 Revised

struct DeliveryView: View {
    @Binding var morningEnabled: Bool
    @Binding var eveningEnabled: Bool
    @Binding var morningTime: Date
    @Binding var eveningTime: Date
    let onNext: () -> Void
    
    @State private var animationStep = 0
    @State private var showMorningPicker = false
    @State private var showEveningPicker = false
    
    // 4 saat kuralı kontrolü
    private var timesTooClose: Bool {
        guard morningEnabled && eveningEnabled else { return false }
        let calendar = Calendar.current
        let morningMinutes = calendar.component(.hour, from: morningTime) * 60 + calendar.component(.minute, from: morningTime)
        let eveningMinutes = calendar.component(.hour, from: eveningTime) * 60 + calendar.component(.minute, from: eveningTime)
        let diff = abs(eveningMinutes - morningMinutes)
        return diff < 240 && diff > 0 // 4 saat = 240 dakika
    }
    
    // En az 1 slot aktif olmalı
    private var isValid: Bool {
        morningEnabled || eveningEnabled
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // İkon
                Text("📦")
                    .font(.system(size: 56))
                    .opacity(animationStep >= 1 ? 1 : 0)
                    .scaleEffect(animationStep >= 1 ? 1 : 0.5)
                    .padding(.bottom, 8)
                
                Text("onboarding.delivery.title".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(animationStep >= 2 ? 1 : 0)
                
                Text("onboarding.delivery.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .opacity(animationStep >= 2 ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Teslimat Slotları - v2.1 Yeni Tasarım
            VStack(spacing: 16) {
                // Slot 1: Güne Başlarken
                DeliverySlotCardV2(
                    slotNumber: 1,
                    title: "onboarding.delivery.slot1".localized,
                    subtitle: "onboarding.delivery.slot1.desc".localized,
                    isEnabled: $morningEnabled,
                    time: $morningTime,
                    showPicker: $showMorningPicker,
                    otherEnabled: eveningEnabled,
                    onToggleOff: {
                        // En az 1 aktif kontrolü
                        if !eveningEnabled {
                            morningEnabled = true
                        }
                    }
                )
                .opacity(animationStep >= 3 ? 1 : 0)
                .offset(x: animationStep >= 3 ? 0 : -20)
                
                // Slot 2: Günü Bitirirken
                DeliverySlotCardV2(
                    slotNumber: 2,
                    title: "onboarding.delivery.slot2".localized,
                    subtitle: "onboarding.delivery.slot2.desc".localized,
                    isEnabled: $eveningEnabled,
                    time: $eveningTime,
                    showPicker: $showEveningPicker,
                    otherEnabled: morningEnabled,
                    onToggleOff: {
                        // En az 1 aktif kontrolü
                        if !morningEnabled {
                            eveningEnabled = true
                        }
                    }
                )
                .opacity(animationStep >= 4 ? 1 : 0)
                .offset(x: animationStep >= 4 ? 0 : -20)
                
                // Uyarı: Saatler çok yakın
                if timesTooClose {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                        Text("onboarding.delivery.warning".localized)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Hata: En az 1 slot zorunlu
                if !isValid {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                        Text("onboarding.delivery.minOneRequired".localized)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.3), value: timesTooClose)
            .animation(.easeInOut(duration: 0.3), value: isValid)
            
            Spacer()
            
            // Ana Buton
            Button(action: {
                NotificationManager.shared.requestPermission()
                onNext()
            }) {
                Text("onboarding.delivery.button".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isValid ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.joltYellow : Color.white.opacity(0.1))
                    .cornerRadius(16)
            }
            .disabled(!isValid)
            .opacity(animationStep >= 5 ? 1 : 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) { animationStep = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { animationStep = 2 }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) { animationStep = 3 }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) { animationStep = 4 }
            withAnimation(.easeOut(duration: 0.4).delay(1.3)) { animationStep = 5 }
        }
    }
}

// MARK: - v2.1 Delivery Slot Card

struct DeliverySlotCardV2: View {
    let slotNumber: Int
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    @Binding var time: Date
    @Binding var showPicker: Bool
    let otherEnabled: Bool
    let onToggleOff: () -> Void
    
    private var iconColor: Color {
        slotNumber == 1 ? .orange : .purple
    }
    
    private var icon: String {
        slotNumber == 1 ? "sun.max.fill" : "moon.fill"
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row - fixed height
            HStack(spacing: 12) {
                // Toggle - fixed width
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if !newValue && !otherEnabled {
                            onToggleOff()
                        } else {
                            isEnabled = newValue
                            if !newValue {
                                showPicker = false
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(.joltYellow)
                .frame(width: 51) // Toggle standart genişliği
                
                // Icon - fixed size
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isEnabled ? iconColor : .gray)
                }
                
                // Text - takes remaining space
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isEnabled ? .white : .gray)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // Time Button - fixed width, always show placeholder when disabled
                Button {
                    if isEnabled {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker.toggle()
                        }
                    }
                } label: {
                    Text(timeString)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? .joltYellow : .gray.opacity(0.5))
                        .frame(width: 70)
                        .padding(.vertical, 8)
                        .background(isEnabled ? Color.joltYellow.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .disabled(!isEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            // Inline Time Picker
            if showPicker && isEnabled {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(spacing: 8) {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .frame(height: 150)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker = false
                        }
                    } label: {
                        Text("common.done".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.joltYellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.joltYellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color.white.opacity(isEnabled ? 0.08 : 0.04))
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.25), value: isEnabled)
        .animation(.easeInOut(duration: 0.25), value: showPicker)
    }
}

// MARK: - Legacy DeliverySlotCard (Backward Compatibility)

struct DeliverySlotCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    @Binding var time: Date
    
    var body: some View {
        HStack(spacing: 16) {
            // Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(.joltYellow)
            
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(isEnabled ? 0.2 : 0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isEnabled ? iconColor : .gray)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isEnabled ? .white : .gray)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Time Picker (when enabled)
            if isEnabled {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(.joltYellow)
            }
        }
        .padding(16)
        .background(Color.white.opacity(isEnabled ? 0.08 : 0.04))
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - EKRAN 5: GÜVENLİ GİRİŞ (Training Mode)

struct TrainingModeView: View {
    let onFinish: () -> Void
    @State private var isPulsing = false
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Kalkan İkonu
                ZStack {
                    // Pulse rings - sadece bu animasyonlu
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.5)
                    
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(isPulsing ? 1.6 : 1.0)
                        .opacity(isPulsing ? 0 : 0.3)
                    
                    // Main shield - sabit, animasyonsuz
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 140, height: 140)
                    
                    Image(systemName: "shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.green.opacity(0.5), radius: 20)
                }
                
                // Content - sabit, animasyonsuz (sadece fade-in)
                VStack(spacing: 16) {
                    Text("onboarding.training.title".localized)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1 : 0)
                    
                    Text("onboarding.training.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(showContent ? 1 : 0)
                    
                    // 3 Gün Badge - sabit
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 16))
                        Text("onboarding.training.duration".localized)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                    .opacity(showContent ? 1 : 0)
                }
            }
            
            Spacer()
            
            // Dev Buton - sabit
            Button(action: onFinish) {
                HStack(spacing: 8) {
                    Text("onboarding.training.button".localized)
                    Image(systemName: "bolt.fill")
                }
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.joltYellow)
                .cornerRadius(16)
            }
            .opacity(showContent ? 1 : 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Sadece pulse rings animasyonu - repeatForever
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
            
            // Content fade in - tek seferlik
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Training Mode Banner (For Main App)

struct TrainingModeBanner: View {
    @State private var daysRemaining: Int = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("training.banner.title".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("training.banner.subtitle".localized(with: daysRemaining))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("training.banner.badge".localized)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            daysRemaining = ExpirationService.shared.trainingDaysRemaining()
        }
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

#Preview("Wake Up Call") {
    WakeUpCallView(onNext: {})
        .preferredColorScheme(.dark)
}

#Preview("The Law") {
    TheLawView(onNext: {})
        .preferredColorScheme(.dark)
}

#Preview("Training Mode") {
    TrainingModeView(onFinish: {})
        .preferredColorScheme(.dark)
}
