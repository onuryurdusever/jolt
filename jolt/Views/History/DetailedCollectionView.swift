//
//  DetailedCollectionView.swift
//  jolt
//

import SwiftUI
import SwiftData

struct DetailedCollectionView: View {
    let collection: JoltCollection
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \JoltCollection.createdAt, order: .reverse) private var allCollections: [JoltCollection]
    
    @State private var selectedBookmark: Bookmark?
    @State private var showShareSheet = false
    @State private var bookmarkToShare: Bookmark?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            Color.joltBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Duplicate of History logic but for collection)
                if collection.bookmarks?.isEmpty ?? true {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.joltMutedForeground.opacity(0.5))
                        Text("history.collections.empty".localized)
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(collection.bookmarks ?? []) { bookmark in
                            HistoryItemRow(
                                bookmark: bookmark,
                                onTap: { selectedBookmark = bookmark },
                                onShare: {
                                    bookmarkToShare = bookmark
                                    showShareSheet = true
                                },
                                onDelete: { removeFromCollection(bookmark) },
                                collections: allCollections,
                                onAssign: { col in assignToCollection(bookmark, col) },
                                onRemove: { removeFromCollection(bookmark) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(collection.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("history.collections.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("history.collections.delete".localized, isPresented: $showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                deleteCollection()
            }
        } message: {
            Text("alert.deleteConfirm.message".localized)
        }
        .navigationDestination(item: $selectedBookmark) { bookmark in
            ReaderView(bookmark: bookmark, isArchived: true)
        }
    }
    
    private func removeFromCollection(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.collection = nil
            try? modelContext.save()
        }
    }
    
    private func assignToCollection(_ bookmark: Bookmark, _ collection: JoltCollection) {
        withAnimation {
            bookmark.collection = collection
            try? modelContext.save()
        }
    }
    
    private func deleteCollection() {
        modelContext.delete(collection)
        try? modelContext.save()
        dismiss()
    }
}
