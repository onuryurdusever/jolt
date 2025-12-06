//
//  CollectionPickerView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData

struct CollectionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.createdAt) private var allCollections: [Collection]
    
    let bookmark: Bookmark?
    let onSelect: (Collection?) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Inbox (No Collection)
                        Button(action: {
                            onSelect(nil)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#CCFF00"))
                                    .frame(width: 40, height: 40)
                                    .background(Color(hex: "#CCFF00").opacity(0.15))
                                    .cornerRadius(8)
                                
                                Text("collectionPicker.inbox".localized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if let bookmark = bookmark, !bookmark.isDeleted, bookmark.collection == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "#CCFF00"))
                                }
                            }
                            .padding(12)
                            .background(Color.joltCardBackground)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Collections
                        ForEach(allCollections) { collection in
                            Button(action: {
                                onSelect(collection)
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: collection.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: collection.color))
                                        .frame(width: 40, height: 40)
                                        .background(Color(hex: collection.color).opacity(0.15))
                                        .cornerRadius(8)
                                    
                                    Text(collection.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if let bookmark = bookmark, !bookmark.isDeleted, bookmark.collection?.id == collection.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: collection.color))
                                    }
                                }
                                .padding(12)
                                .background(Color.joltCardBackground)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("reader.moveToCollection".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#CCFF00"))
                }
            }
        }
    }
}
