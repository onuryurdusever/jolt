//
//  EditCollectionView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData

struct EditCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let collection: Collection
    
    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    @State private var showDeleteAlert = false
    
    let colors = [
        "#CCFF00", "#FF6B6B", "#4ECDC4", "#45B7D1", 
        "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE",
        "#85C1E2", "#F8B739"
    ]
    
    let icons = [
        "book.fill", "laptopcomputer", "lightbulb.fill", "star.fill",
        "heart.fill", "flame.fill", "bolt.fill", "flag.fill",
        "bookmark.fill", "newspaper.fill", "graduationcap.fill",
        "briefcase.fill", "house.fill", "cart.fill"
    ]
    
    init(collection: Collection) {
        self.collection = collection
        _name = State(initialValue: collection.name)
        _selectedColor = State(initialValue: collection.color)
        _selectedIcon = State(initialValue: collection.icon)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview
                        VStack(spacing: 16) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: selectedColor))
                                .frame(width: 100, height: 100)
                                .background(Color(hex: selectedColor).opacity(0.15))
                                .cornerRadius(20)
                            
                            Text(name.isEmpty ? "Koleksiyon Adı" : name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 20)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("editCollection.name".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            TextField("collection.namePlaceholder".localized, text: $name)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.joltCardBackground)
                                .cornerRadius(8)
                        }
                        
                        // Color Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("editCollection.color".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(colors, id: \.self) { color in
                                    Button(action: { selectedColor = color }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 50, height: 50)
                                            
                                            if selectedColor == color {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Icon Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("editCollection.icon".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color.joltCardBackground)
                                                .frame(width: 50, height: 50)
                                            
                                            Image(systemName: icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : .gray)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Delete Button
                        VStack(spacing: 12) {
                            Divider()
                                .background(Color.joltCardBackground)
                            
                            Button(action: { showDeleteAlert = true }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("editCollection.deleteCollection".localized)
                                    Spacer()
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("collection.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveChanges()
                    }
                    .foregroundColor(Color(hex: "#CCFF00"))
                    .disabled(name.isEmpty)
                }
            }
            .alert("collection.deleteConfirm.title".localized, isPresented: $showDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                
                Button("collection.deleteConfirm.keepItems".localized, role: .destructive) {
                    deleteCollectionOnly()
                }
                
                Button("collection.deleteConfirm.deleteAll".localized, role: .destructive) {
                    deleteCollectionWithBookmarks()
                }
            } message: {
                let readyCount = collection.bookmarks.filter { $0.status == .ready }.count
                let totalCount = collection.bookmarks.count
                
                if readyCount > 0 {
                    Text("editCollection.statsReady".localized(with: readyCount, totalCount))
                } else {
                    Text("editCollection.statsTotal".localized(with: totalCount))
                }
            }
        }
    }
    
    private func saveChanges() {
        collection.name = name
        collection.color = selectedColor
        collection.icon = selectedIcon
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to save collection: \(error)")
        }
    }
    
    private func deleteCollectionOnly() {
        // Explicitly move all bookmarks to Inbox (collection = nil)
        for bookmark in collection.bookmarks {
            bookmark.collection = nil
        }
        
        // Then delete the collection
        modelContext.delete(collection)
        
        do {
            try modelContext.save()
            print("✅ Collection deleted, \(collection.bookmarks.count) bookmarks moved to Inbox")
            dismiss()
        } catch {
            print("❌ Failed to delete collection: \(error)")
        }
    }
    
    private func deleteCollectionWithBookmarks() {
        // Delete ALL bookmarks in this collection (User intent: "Trash everything")
        let bookmarksToDelete = collection.bookmarks
        
        print("🗑️ Deleting collection and \(bookmarksToDelete.count) bookmarks")
        
        // Delete all bookmarks
        for bookmark in bookmarksToDelete {
            modelContext.delete(bookmark)
        }
        
        // Then delete the collection
        modelContext.delete(collection)
        
        do {
            try modelContext.save()
            print("✅ Collection and all content deleted")
            dismiss()
        } catch {
            print("❌ Failed to delete collection and bookmarks: \(error)")
        }
    }
}

#Preview {
    EditCollectionView(collection: Collection(
        userID: "preview",
        name: "Tech Articles",
        color: "#CCFF00",
        icon: "laptopcomputer"
    ))
    .modelContainer(for: Collection.self, inMemory: true)
}
