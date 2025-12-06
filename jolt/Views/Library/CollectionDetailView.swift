//
//  CollectionDetailView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let collection: Collection
    @State private var selectedBookmark: Bookmark?
    @State private var showCollectionPicker = false
    @State private var bookmarkToMove: Bookmark?
    
    private var bookmarksInCollection: [Bookmark] {
        collection.bookmarks.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ZStack {
            Color.joltBackground
                .ignoresSafeArea()
            
            if bookmarksInCollection.isEmpty {
                emptyState
            } else {
                bookmarkList
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBookmark) { bookmark in
            ReaderView(bookmark: bookmark, isArchived: bookmark.status == .archived)
        }
        .sheet(isPresented: $showCollectionPicker) {
            if let bookmark = bookmarkToMove {
                CollectionPickerView(bookmark: bookmark) { targetCollection in
                    moveBookmark(bookmark, to: targetCollection)
                    showCollectionPicker = false
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: collection.icon)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: collection.color), Color(hex: collection.color).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: collection.color).opacity(0.3), radius: 12)
            
            VStack(spacing: 12) {
                Text("collectionDetail.empty".localized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("collectionDetail.emptyDesc".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var bookmarkList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: collection.icon)
                        .foregroundColor(Color(hex: collection.color))
                    Text("collectionDetail.itemsCount".localized(with: bookmarksInCollection.count))
                        .foregroundColor(.joltMutedForeground)
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Bookmarks
                ForEach(bookmarksInCollection) { bookmark in
                    LibraryBookmarkCard(
                        bookmark: bookmark,
                        isSelectionMode: false,
                        isSelected: false,
                        onTap: {
                            selectedBookmark = bookmark
                        },
                        onStar: {
                            toggleStar(bookmark)
                        },
                        onDelete: {
                            deleteBookmark(bookmark)
                        },
                        onMove: {
                            bookmarkToMove = bookmark
                            showCollectionPicker = true
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    private func toggleStar(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.isStarred = !(bookmark.isStarred ?? false)
        }
        try? modelContext.save()
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        withAnimation {
            modelContext.delete(bookmark)
            try? modelContext.save()
        }
    }
    
    private func moveBookmark(_ bookmark: Bookmark, to targetCollection: Collection?) {
        withAnimation {
            bookmark.collection = targetCollection
            try? modelContext.save()
        }
    }
    
    private func joltBookmark(_ bookmark: Bookmark) {
        Task { @MainActor in
            withAnimation {
                bookmark.status = .archived
                bookmark.readAt = Date()
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collection: Collection(
            userID: "preview",
            name: "Tech Articles",
            color: "#CCFF00",
            icon: "laptopcomputer"
        ))
        .modelContainer(for: [Bookmark.self, Collection.self], inMemory: true)
    }
}
