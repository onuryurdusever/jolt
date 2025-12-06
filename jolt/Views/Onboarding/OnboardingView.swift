//
//  OnboardingView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import UserNotifications
import SwiftData

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    
    // Routine State
    @State private var morningTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var eveningTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    
    private let totalSteps = 7
    
    var body: some View {
        ZStack {
            Color.joltBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Indicator
                if currentStep > 0 && currentStep < totalSteps - 1 {
                    ProgressBar(current: currentStep, total: totalSteps - 1)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                }
                
                // Content
                TabView(selection: $currentStep) {
                    ProblemView(onNext: nextStep)
                        .tag(0)
                    
                    SolutionView(onNext: nextStep)
                        .tag(1)
                    
                    DemoView(onNext: nextStep)
                        .tag(2)
                    
                    RoutineSetupView(
                        morningTime: $morningTime,
                        eveningTime: $eveningTime,
                        onNext: nextStep
                    )
                    .tag(3)
                    
                    PermissionView(onNext: nextStep)
                        .tag(4)
                    
                    WidgetSiriView(onNext: nextStep)
                        .tag(5)
                    
                    ActivationView(onFinish: completeOnboarding)
                        .tag(6)
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
        // 1. Create Routines
        let calendar = Calendar.current
        
        // Morning Routine (Mon-Fri)
        let morningHour = calendar.component(.hour, from: morningTime)
        let morningMinute = calendar.component(.minute, from: morningTime)
        
        let morningRoutine = Routine(
            name: "routines.name.morning".localized,
            icon: "sun.max.fill",
            hour: morningHour,
            minute: morningMinute,
            days: [2, 3, 4, 5, 6], // Mon-Fri
            isEnabled: true
        )
        
        // Evening Routine (Daily)
        let eveningHour = calendar.component(.hour, from: eveningTime)
        let eveningMinute = calendar.component(.minute, from: eveningTime)
        
        let eveningRoutine = Routine(
            name: "routines.name.evening".localized,
            icon: "moon.fill",
            hour: eveningHour,
            minute: eveningMinute,
            days: [1, 2, 3, 4, 5, 6, 7],
            isEnabled: true
        )
        
        // Weekend Routine (Sat-Sun, later morning)
        let weekendRoutine = Routine(
            name: "routines.name.weekend".localized,
            icon: "cup.and.saucer.fill",
            hour: 11,
            minute: 0,
            days: [1, 7], // Sun, Sat
            isEnabled: true
        )
        
        modelContext.insert(morningRoutine)
        modelContext.insert(eveningRoutine)
        modelContext.insert(weekendRoutine)
        
        // 2. Save Context
        try? modelContext.save()
        
        // 3. Schedule Initial Notifications
        NotificationManager.shared.scheduleSmartNotifications(modelContext: modelContext)
        
        // 4. Finish
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

// MARK: - Stat Row (Aligned)
struct StatRow: View {
    let emoji: String
    let number: String
    let label: String
    let numberColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 44))
                .frame(width: 56, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(number)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(numberColor)
                
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Screen 1: The Problem (Empati)
struct ProblemView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Animated Stats
                VStack(alignment: .leading, spacing: 24) {
                    // Tab count
                    StatRow(
                        emoji: "📑",
                        number: "47",
                        label: "onboarding.problem.tabs".localized,
                        numberColor: .white
                    )
                    .opacity(animationStep >= 1 ? 1 : 0)
                    .offset(y: animationStep >= 1 ? 0 : 20)
                    
                    // Bookmark count
                    StatRow(
                        emoji: "📌",
                        number: "312",
                        label: "onboarding.problem.saved".localized,
                        numberColor: .white
                    )
                    .opacity(animationStep >= 2 ? 1 : 0)
                    .offset(y: animationStep >= 2 ? 0 : 20)
                    
                    // Read count
                    StatRow(
                        emoji: "💀",
                        number: "0",
                        label: "onboarding.problem.read".localized,
                        numberColor: Color.red.opacity(0.8)
                    )
                    .opacity(animationStep >= 3 ? 1 : 0)
                    .offset(y: animationStep >= 3 ? 0 : 20)
                }
                .padding(.horizontal, 40)
                
                // Question
                Text("onboarding.intro.question".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(animationStep >= 4 ? 1 : 0)
                    .padding(.top, 16)
            }
            
            Spacer()
            
            // CTA Button
            Button(action: onNext) {
                Text("onboarding.intro.answer".localized)
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
            // Staggered animation
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { animationStep = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { animationStep = 2 }
            withAnimation(.easeOut(duration: 0.5).delay(1.1)) { animationStep = 3 }
            withAnimation(.easeOut(duration: 0.5).delay(1.6)) { animationStep = 4 }
        }
    }
}

// MARK: - Screen 2: The Solution (Değer)
struct SolutionView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Logo
                Image(systemName: "bolt.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.joltYellow)
                    .shadow(color: Color.joltYellow.opacity(0.5), radius: 20)
                
                // Headline
                Text("onboarding.philosophy.title".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Value Props
                VStack(alignment: .leading, spacing: 20) {
                    ValuePropRow(
                        emoji: "📥",
                        text: "onboarding.solution.save".localized,
                        highlight: "onboarding.solution.saveHint".localized
                    )
                    .opacity(animationStep >= 1 ? 1 : 0)
                    .offset(x: animationStep >= 1 ? 0 : -20)
                    
                    ValuePropRow(
                        emoji: "🔔",
                        text: "onboarding.solution.remind".localized,
                        highlight: "onboarding.solution.remindHint".localized
                    )
                    .opacity(animationStep >= 2 ? 1 : 0)
                    .offset(x: animationStep >= 2 ? 0 : -20)
                    
                    ValuePropRow(
                        emoji: "⚡",
                        text: "onboarding.solution.finish".localized,
                        highlight: "onboarding.solution.finishHint".localized
                    )
                    .opacity(animationStep >= 3 ? 1 : 0)
                    .offset(x: animationStep >= 3 ? 0 : -20)
                }
                .padding(.horizontal, 24)
                
                // Tagline
                Text("onboarding.unread.title".localized)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .opacity(animationStep >= 4 ? 1 : 0)
            }
            
            Spacer()
            
            Button(action: onNext) {
                Text("onboarding.unread.action".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { animationStep = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { animationStep = 2 }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) { animationStep = 3 }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) { animationStep = 4 }
        }
    }
}

struct ValuePropRow: View {
    let emoji: String
    let text: String
    let highlight: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 24))
            
            Text(text)
                .font(.system(size: 18))
                .foregroundColor(.white)
            
            Text(highlight)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.joltYellow)
        }
    }
}

// MARK: - Screen 3: The Demo (Share Extension)
struct DemoView: View {
    let onNext: () -> Void
    @State private var demoStep = 0
    @State private var showShareSheet = false
    @State private var selectedTime = "onboarding.capture.morning"
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    Text("onboarding.capture.title".localized)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("onboarding.capture.subtitle".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Demo Animation
                ZStack {
                    // Phone Frame
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 280, height: 380)
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.black)
                        )
                    
                    VStack(spacing: 0) {
                        // Safari Bar
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 32)
                                .overlay(
                                    Text("onboarding.capture.example".localized)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Content placeholder
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 200, height: 12)
                        }
                        .padding(16)
                        
                        Spacer()
                        
                        // Share Sheet Simulation
                        if showShareSheet {
                            VStack(spacing: 16) {
                                // Header
                                HStack {
                                    Circle()
                                        .fill(Color.joltYellow)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(.black)
                                                .font(.system(size: 18))
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("shareExtension.joltIt".localized)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("medium.com")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Time Selection
                                HStack(spacing: 8) {
                                    ForEach(["onboarding.capture.morning", "onboarding.capture.evening", "onboarding.capture.weekend"], id: \.self) { timeKey in
                                        Text(timeKey.localized)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(selectedTime == timeKey ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(selectedTime == timeKey ? Color.joltYellow : Color.white.opacity(0.1))
                                            )
                                            .onTapGesture {
                                                withAnimation { selectedTime = timeKey }
                                            }
                                    }
                                }
                                
                                // Save Button
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14))
                                    Text("onboarding.capture.save".localized)
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.joltYellow)
                                .cornerRadius(12)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "#1C1C1E"))
                            )
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(width: 280, height: 380)
                    
                    // Share Button Animation
                    if demoStep == 1 {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 48))
                            .foregroundColor(.joltYellow)
                            .offset(y: 60)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 400)
            }
            
            Spacer()
            
            Button(action: onNext) {
                Text("onboarding.capture.understood".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
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
                    demoStep = 2
                    showShareSheet = true
                }
            }
        }
    }
}

// MARK: - Screen 4: Routine Setup
struct RoutineSetupView: View {
    @Binding var morningTime: Date
    @Binding var eveningTime: Date
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.routine.title".localized)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("onboarding.routine.subtitle".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 60)
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 16) {
                // Morning
                RoutineTimeCard(
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "onboarding.routine.morning".localized,
                    subtitle: "onboarding.routine.morningDesc".localized,
                    time: $morningTime
                )
                
                // Evening
                RoutineTimeCard(
                    icon: "moon.fill",
                    iconColor: .purple,
                    title: "onboarding.routine.evening".localized,
                    subtitle: "onboarding.routine.eveningDesc".localized,
                    time: $eveningTime
                )
                
                // Info
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.joltYellow)
                    Text("onboarding.routine.example".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: onNext) {
                Text("onboarding.routine.continue".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct RoutineTimeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var time: Date
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Time Picker
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.joltYellow)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Screen 5: Permission
struct PermissionView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.joltYellow.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.joltYellow)
                }
                
                // Title
                VStack(spacing: 12) {
                    Text("onboarding.notification.title".localized)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("onboarding.notification.subtitle".localized)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.joltYellow)
                }
                
                // Promises
                VStack(alignment: .leading, spacing: 16) {
                    PromiseRow(icon: "clock", text: "onboarding.notification.promise1".localized)
                        .opacity(animationStep >= 1 ? 1 : 0)
                    
                    PromiseRow(icon: "tray", text: "onboarding.notification.promise2".localized)
                        .opacity(animationStep >= 2 ? 1 : 0)
                    
                    PromiseRow(icon: "hand.raised", text: "onboarding.notification.promise3".localized)
                        .opacity(animationStep >= 3 ? 1 : 0)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    NotificationManager.shared.requestPermission()
                    onNext()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                        Text("onboarding.notification.allow".localized)
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
                }
                
                Button(action: onNext) {
                    Text("onboarding.notification.later".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { animationStep = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) { animationStep = 2 }
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) { animationStep = 3 }
        }
    }
}

struct PromiseRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
            
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Screen 6: Widget & Siri
struct WidgetSiriView: View {
    let onNext: () -> Void
    @State private var animationStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 8) {
                    Text("onboarding.widgets.title".localized)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("onboarding.widgets.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                // Widget Previews - Real widget designs
                HStack(spacing: 12) {
                    // Streak Widget Preview
                    OnboardingStreakWidgetPreview()
                        .opacity(animationStep >= 1 ? 1 : 0)
                        .scaleEffect(animationStep >= 1 ? 1 : 0.8)
                    
                    // Daily Goal Widget Preview
                    OnboardingGoalWidgetPreview()
                        .opacity(animationStep >= 2 ? 1 : 0)
                        .scaleEffect(animationStep >= 2 ? 1 : 0.8)
                }
                .padding(.horizontal, 24)
                
                // Widget descriptions
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("onboarding.widgets.streak".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "target")
                            .foregroundColor(.green)
                        Text("onboarding.widgets.goal".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .opacity(animationStep >= 3 ? 1 : 0)
                
                // Siri Section
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.joltYellow)
                        Text("onboarding.widgets.siriTitle".localized)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .opacity(animationStep >= 4 ? 1 : 0)
                    
                    VStack(spacing: 8) {
                        SiriExampleBubble(text: "onboarding.widgets.siriExample1".localized)
                            .opacity(animationStep >= 5 ? 1 : 0)
                            .offset(y: animationStep >= 5 ? 0 : 10)
                        
                        SiriExampleBubble(text: "onboarding.widgets.siriExample2".localized)
                            .opacity(animationStep >= 6 ? 1 : 0)
                            .offset(y: animationStep >= 6 ? 0 : 10)
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            Button(action: onNext) {
                Text("onboarding.widgets.continue".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) { animationStep = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) { animationStep = 2 }
            withAnimation(.easeOut(duration: 0.3).delay(0.7)) { animationStep = 3 }
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) { animationStep = 4 }
            withAnimation(.easeOut(duration: 0.3).delay(1.2)) { animationStep = 5 }
            withAnimation(.easeOut(duration: 0.3).delay(1.4)) { animationStep = 6 }
        }
    }
}

// MARK: - Onboarding Streak Widget Preview (matches real StreakWidget design)
struct OnboardingStreakWidgetPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            // Streak Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.57) // 4/7 days
                    .stroke(
                        LinearGradient(
                            colors: [Color.joltYellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("4")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            Text("DAY STREAK")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(1)
        }
        .frame(width: 130, height: 130)
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
        .cornerRadius(20)
    }
}

// MARK: - Onboarding Goal Widget Preview (matches real DailyGoalWidget design)
struct OnboardingGoalWidgetPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.66) // 2/3 complete
                    .stroke(
                        LinearGradient(
                            colors: [Color.joltYellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("2")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/3")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            Text("DAILY GOAL")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(1)
        }
        .frame(width: 130, height: 130)
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
        .cornerRadius(20)
    }
}

struct SiriExampleBubble: View {
    let text: String
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .italic()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 7: Activation (First Jolt)
struct ActivationView: View {
    let onFinish: () -> Void
    @State private var showSuccess = false
    @State private var clipboardURL: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if showSuccess {
                // Success State
                VStack(spacing: 24) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.joltYellow)
                    
                    Text("onboarding.complete.title".localized)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("onboarding.complete.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Main Content
                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.joltYellow.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.joltYellow)
                    }
                    
                    VStack(spacing: 12) {
                        Text("onboarding.complete.lastStep".localized)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("onboarding.complete.lastStepDesc".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(number: "1", text: "onboarding.complete.tip1".localized)
                        TipRow(number: "2", text: "onboarding.complete.tip2".localized)
                        TipRow(number: "3", text: "onboarding.complete.tip3".localized)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    if showSuccess {
                        onFinish()
                    } else {
                        showSuccess = true
                    }
                }
            }) {
                Text(showSuccess ? "onboarding.complete.letsGo".localized : "onboarding.complete.ready".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.joltYellow)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct TipRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.joltYellow)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
