//
//  CollectionsListView.swift
//  jolt
//

import SwiftUI
import SwiftData

struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \JoltCollection.createdAt, order: .reverse) private var collections: [JoltCollection]
    
    @State private var showNewCollectionSheet = false
    @State private var collectionToDelete: JoltCollection?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground.ignoresSafeArea()
                
                if collections.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(collections) { collection in
                            CollectionListRow(collection: collection)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        collectionToDelete = collection
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("common.delete".localized, systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .alert("history.collections.delete".localized, isPresented: $showDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) {
                    if let collection = collectionToDelete {
                        deleteCollection(collection)
                    }
                }
            } message: {
                Text("alert.deleteConfirm.message".localized)
            }
            .navigationTitle("history.filter.collections".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewCollectionSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .sheet(isPresented: $showNewCollectionSheet) {
                NewCollectionSheet()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.joltMutedForeground.opacity(0.5))
            
            Text("history.collections.empty".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.joltForeground)
            
            Button {
                showNewCollectionSheet = true
            } label: {
                Text("history.collections.add".localized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.joltGreen)
                    .cornerRadius(20)
            }
        }
    }
    
    private func deleteCollection(_ collection: JoltCollection) {
        modelContext.delete(collection)
        try? modelContext.save()
    }
}

struct CollectionListRow: View {
    let collection: JoltCollection
    
    var body: some View {
        NavigationLink(destination: DetailedCollectionView(collection: collection)) {
            HStack(spacing: 16) {
                Text(collection.emoji ?? "📁")
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
                    .background(Color.joltCardBackground)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.joltForeground)
                    
                    Text("history.collections.itemCount".localized(with: collection.bookmarks?.count ?? 0))
                        .font(.system(size: 13))
                        .foregroundColor(.joltMutedForeground)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.joltMutedForeground.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
