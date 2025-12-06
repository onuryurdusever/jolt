//
//  LanguageManager.swift
//  jolt
//
//  Language selection and management
//

import SwiftUI
import Combine

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case turkish = "tr"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt-BR"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "settings.language.system".localized
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        case .portuguese: return "Português (BR)"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "简体中文"
        }
    }
    
    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇺🇸"
        case .turkish: return "🇹🇷"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        }
    }
}

// MARK: - Language Manager

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = "system"
    
    @Published var currentLanguage: AppLanguage = .system
    
    private init() {
        currentLanguage = AppLanguage(rawValue: selectedLanguageCode) ?? .system
    }
    
    func setLanguage(_ language: AppLanguage) {
        selectedLanguageCode = language.rawValue
        currentLanguage = language
        
        if language == .system {
            // Remove override, use system language
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            // Override app language
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        
        // Sync to shared UserDefaults for consistency
        UserDefaults.standard.synchronize()
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    var effectiveLanguageCode: String {
        if currentLanguage == .system {
            return Locale.current.language.languageCode?.identifier ?? "en"
        }
        return currentLanguage.rawValue
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Language Picker View

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: AppLanguage = .system
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground.ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                selectLanguage(language)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(language.flag)
                                        .font(.title2)
                                    
                                    Text(language.displayName)
                                        .font(.iosBody)
                                        .foregroundColor(.joltForeground)
                                    
                                    Spacer()
                                    
                                    if selectedLanguage == language {
                                        Image(systemName: "checkmark")
                                            .font(.iosBody)
                                            .foregroundColor(.joltYellow)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("settings.language.select".localized)
                            .foregroundColor(.joltMutedForeground)
                    } footer: {
                        Text("settings.language.restart".localized)
                            .foregroundColor(.joltMutedForeground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("settings.language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(.joltYellow)
                }
            }
            .onAppear {
                selectedLanguage = languageManager.currentLanguage
            }
        }
        .presentationDetents([.medium])
    }
    
    private func selectLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        languageManager.setLanguage(language)
        
        // Give haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    LanguagePickerView()
}
