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
    
    var id: String { rawValue }
    
    var displayName: String {
        return "Türkçe"
    }
    
    var flag: String {
        return "🇹🇷"
    }
}

// MARK: - Language Manager

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // Turkish is the only supported language
    var currentLanguage: AppLanguage = .turkish
    
    private init() {}
    
    // No-op for single language app
    func setLanguage(_ language: AppLanguage) {}
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
