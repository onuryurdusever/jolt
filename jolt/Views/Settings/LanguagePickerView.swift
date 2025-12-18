//
//  LanguageManager.swift
//  jolt
//
//  Language selection and management
//

import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case german = "de"
    case japanese = "ja"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        }
    }
    
    var flag: String {
        switch self {
        case .turkish: return "🇹🇷"
        case .english: return "🇺🇸"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        }
    }
    
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
}

// MARK: - Language Manager

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("app_language", store: UserDefaults(suiteName: "group.com.jolt.shared")) private var storedLanguage: String = AppLanguage.turkish.rawValue
    
    @Published var currentLanguage: AppLanguage = .turkish
    
    var bundle: Bundle {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
    
    private init() {
        if let lang = AppLanguage(rawValue: storedLanguage) {
            self.currentLanguage = lang
        }
    }
    
    /// Non-isolated access to the current bundle for background thread localization
    nonisolated static var currentBundle: Bundle {
        let stored = UserDefaults(suiteName: "group.com.jolt.shared")?.string(forKey: "app_language") ?? "tr"
        if let path = Bundle.main.path(forResource: stored, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        storedLanguage = language.rawValue
        
        // Notify the app that language has changed
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
        
        // Force UI update
        objectWillChange.send()
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
    @State private var selectedLanguage: AppLanguage = .turkish
    
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
