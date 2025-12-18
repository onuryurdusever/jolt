//
//  NewCollectionSheet.swift
//  jolt
//

import SwiftUI
import SwiftData

struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = "📁"
    
    let emojis = ["📁", "📚", "🎨", "💻", "🧠", "💼", "🎮", "🎬", "🎵", "📍", "⭐️", "🚀", "💡", "🛠"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Emoji Picker
                    VStack(spacing: 12) {
                        Text(emoji)
                            .font(.system(size: 64))
                            .padding(20)
                            .background(Color.joltCardBackground)
                            .clipShape(Circle())
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(emojis, id: \.self) { e in
                                    Button {
                                        emoji = e
                                    } label: {
                                        Text(e)
                                            .font(.title2)
                                            .padding(10)
                                            .background(emoji == e ? Color.joltGreen.opacity(0.2) : Color.joltCardBackground)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("history.collections.name".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.joltMutedForeground)
                            .padding(.leading, 4)
                        
                        TextField("history.collections.namePlaceholder".localized, text: $name)
                            .padding(16)
                            .background(Color.joltCardBackground)
                            .cornerRadius(12)
                            .foregroundColor(.joltForeground)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button {
                        createCollection()
                    } label: {
                        Text("common.create".localized)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? Color.gray : Color.joltGreen)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("history.collections.new".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createCollection() {
        let newCollection = JoltCollection(name: name, emoji: emoji)
        modelContext.insert(newCollection)
        try? modelContext.save()
        dismiss()
    }
}
