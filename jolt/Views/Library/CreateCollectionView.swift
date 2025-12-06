//
//  CreateCollectionView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData

struct CreateCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var name = ""
    @State private var selectedColor = "#CCFF00"
    @State private var selectedIcon = "folder.fill"
    
    private let colors = [
        "#CCFF00", "#FF6B6B", "#4ECDC4", "#FFE66D",
        "#A8DADC", "#FF8B94", "#B4A7D6", "#95E1D3"
    ]
    
    private let icons = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "flag.fill", "tag.fill", "paperclip", "lightbulb.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("createCollection.name".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("collection.namePlaceholder".localized, text: $name)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.joltCardBackground)
                            .cornerRadius(12)
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("createCollection.color".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: "#CCFF00"), lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                    
                    // Icon Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("createCollection.icon".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : .gray)
                                    .frame(width: 50, height: 50)
                                    .background(Color.joltCardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: selectedColor), lineWidth: selectedIcon == icon ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Create Button
                    Button(action: createCollection) {
                        Text("createCollection.create".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#CCFF00"))
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .navigationTitle("collection.create".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func createCollection() {
        guard let userID = authService.currentUserID else { return }
        
        let collection = Collection(
            userID: userID,
            name: name,
            color: selectedColor,
            icon: selectedIcon
        )
        
        modelContext.insert(collection)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    CreateCollectionView()
        .modelContainer(for: Collection.self, inMemory: true)
        .environmentObject(AuthService.shared)
}
