//
//  LibraryView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var allBookmarks: [Bookmark]
    @Query(sort: \Collection.createdAt) private var allCollections: [Collection]
    @ObservedObject private var syncService = SyncService.shared
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all
    @State private var selectedType: BookmarkType? = nil
    @State private var selectedCollection: Collection? = nil
    @State private var sortOption: SortOption = .newestFirst
    @State private var viewMode: ViewMode = .list
    @State private var showSortSheet = false
    @State private var showCreateCollection = false
    @State private var selectedBookmark: Bookmark?
    @State private var navigationPath = NavigationPath()
    
    // Selection Mode
    @State private var isSelectionMode = false
    @State private var selectedBookmarks = Set<UUID>()
    @State private var showBulkDeleteAlert = false
    @State private var showBulkCollectionPicker = false
    
    // Collection Management
    @State private var collectionToEdit: Collection?
    @State private var showDeleteCollectionAlert = false
    @State private var collectionToDelete: Collection?
    
    // MARK: - Enums
    
    enum StatusFilter: String, CaseIterable {
        case all
        case unread
        case read
        case starred
        
        var title: String {
            switch self {
            case .all: return "library.filter.all".localized
            case .unread: return "library.filter.unread".localized
            case .read: return "library.filter.read".localized
            case .starred: return "library.filter.starred".localized
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case newestFirst
        case oldestFirst
        case titleAZ
        case readingTime
        case progress
        
        var title: String {
            switch self {
            case .newestFirst: return "library.sort.newest".localized
            case .oldestFirst: return "library.sort.oldest".localized
            case .titleAZ: return "library.sort.az".localized
            case .readingTime: return "library.sort.readingTime".localized
            case .progress: return "library.sort.progress".localized
            }
        }
        
        var icon: String {
            switch self {
            case .newestFirst: return "arrow.down"
            case .oldestFirst: return "arrow.up"
            case .titleAZ: return "textformat.abc"
            case .readingTime: return "clock"
            case .progress: return "chart.bar.fill"
            }
        }
    }
    
    enum ViewMode {
        case list
        case grid
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredBookmarks: [Bookmark] {
        var bookmarks = allBookmarks
        
        // Status filter
        switch selectedStatus {
        case .all:
            break
        case .unread:
            bookmarks = bookmarks.filter { $0.status != .archived }
        case .read:
            bookmarks = bookmarks.filter { $0.status == .archived }
        case .starred:
            bookmarks = bookmarks.filter { $0.isStarred == true }
        }
        
        // Type filter
        if let type = selectedType {
            bookmarks = bookmarks.filter { $0.type == type }
        }
        
        // Collection filter
        if let collection = selectedCollection {
            bookmarks = bookmarks.filter { $0.collection?.id == collection.id }
        }
        
        // Search filter
        if !searchText.isEmpty {
            bookmarks = bookmarks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.domain.localizedCaseInsensitiveContains(searchText) ||
                ($0.excerpt?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.userNote?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Sorting
        bookmarks = sortBookmarks(bookmarks)
        
        return bookmarks
    }
    
    private func sortBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        switch sortOption {
        case .newestFirst:
            return bookmarks.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return bookmarks.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return bookmarks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .readingTime:
            return bookmarks.sorted { $0.readingTimeMinutes < $1.readingTimeMinutes }
        case .progress:
            return bookmarks.sorted { ($0.lastScrollPercentage ?? 0) > ($1.lastScrollPercentage ?? 0) }
        }
    }
    
    private var statusCounts: (all: Int, unread: Int, read: Int, starred: Int) {
        let all = allBookmarks.count
        let unread = allBookmarks.filter { $0.status != .archived }.count
        let read = allBookmarks.filter { $0.status == .archived }.count
        let starred = allBookmarks.filter { $0.isStarred == true }.count
        return (all, unread, read, starred)
    }
    
    private var typeCounts: [BookmarkType: Int] {
        var counts: [BookmarkType: Int] = [:]
        for bookmark in allBookmarks {
            counts[bookmark.type, default: 0] += 1
        }
        return counts
    }
    
    private var inboxCount: Int {
        allBookmarks.filter { $0.collection == nil }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    libraryHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Search + View Toggle
                            searchSection
                                .padding(.horizontal, 20)
                            
                            // Status Segment
                            statusSegment
                                .padding(.horizontal, 20)
                            
                            // Quick Access (Type Filters)
                            if selectedCollection == nil && selectedStatus != .starred {
                                quickAccessSection
                            }
                            
                            // Collections Section
                            if selectedType == nil && selectedStatus == .all {
                                collectionsSection
                                    .padding(.horizontal, 20)
                            }
                            
                            // Bookmarks List/Grid
                            bookmarksSection
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, isSelectionMode ? 100 : 32)
                    }
                    
                    // Batch Action Bar
                    if isSelectionMode {
                        batchActionBar
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedBookmark) { bookmark in
                ReaderView(bookmark: bookmark, isArchived: bookmark.status == .archived)
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionView()
            }
            .sheet(item: $collectionToEdit) { collection in
                EditCollectionView(collection: collection)
            }
            .sheet(isPresented: $showSortSheet) {
                sortOptionsSheet
            }
            .sheet(isPresented: $showBulkCollectionPicker) {
                CollectionPickerView(bookmark: nil) { collection in
                    moveSelectedBookmarks(to: collection)
                    showBulkCollectionPicker = false
                }
            }
            .alert("library.deleteSelected.title".localized, isPresented: $showBulkDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("library.deleteSelected.confirm".localized(with: selectedBookmarks.count), role: .destructive) {
                    deleteSelectedBookmarks()
                }
            } message: {
                Text("library.deleteConfirm".localized(with: selectedBookmarks.count))
            }
            .alert("collection.delete.title".localized, isPresented: $showDeleteCollectionAlert) {
                Button("common.cancel".localized, role: .cancel) { collectionToDelete = nil }
                Button("collection.delete.keepItems".localized, role: .destructive) {
                    if let collection = collectionToDelete {
                        deleteCollectionOnly(collection)
                    }
                }
                Button("collection.delete.deleteAll".localized, role: .destructive) {
                    if let collection = collectionToDelete {
                        deleteCollectionWithBookmarks(collection)
                    }
                }
            } message: {
                if let collection = collectionToDelete {
                    Text("library.collectionItems".localized(with: collection.name, collection.bookmarks.count))
                }
            }
            .onChange(of: allCollections) { _, newValue in
                CollectionSyncService.shared.syncCollectionsToAppGroup(collections: newValue)
            }
        }
    }
    
    // MARK: - Header
    
    private var libraryHeader: some View {
        HStack {
            if isSelectionMode {
                Button("common.done".localized) {
                    toggleSelectionMode()
                }
                .foregroundColor(.joltYellow)
                
                Spacer()
                
                Text("library.selectedCount".localized(with: selectedBookmarks.count))
                    .font(.iosHeadline)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Button("library.selectAll".localized) {
                    selectAll()
                }
                .foregroundColor(.joltYellow)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("library.title".localized)
                        .font(.iosFootnote)
                        .foregroundColor(.joltMutedForeground)
                        .tracking(1)
                    
                    Text("library.subtitle".localized)
                        .font(.iosLargeTitle)
                        .foregroundColor(.joltForeground)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Sync Button
                    Button {
                        Task {
                            await syncService.syncPendingBookmarks(context: modelContext)
                        }
                    } label: {
                        if syncService.isSyncing {
                            ProgressView()
                                .tint(.joltYellow)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.joltYellow)
                        }
                    }
                    .disabled(syncService.isSyncing)
                    
                    // Selection Mode
                    Button {
                        toggleSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.joltMutedForeground)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.joltMutedForeground)
                
                TextField("library.search.placeholder".localized, text: $searchText)
                    .foregroundColor(.joltForeground)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.joltMutedForeground)
                    }
                }
            }
            .padding(12)
            .background(Color.joltCardBackground)
            .cornerRadius(12)
            
            // View Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = viewMode == .list ? .grid : .list
                }
            } label: {
                Image(systemName: viewMode.icon)
                    .font(.iosBody)
                    .foregroundColor(.joltMutedForeground)
                    .frame(width: 44, height: 44)
                    .background(Color.joltCardBackground)
                    .cornerRadius(12)
            }
            
            // Sort Button
            Button {
                showSortSheet = true
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.iosBody)
                    .foregroundColor(.joltMutedForeground)
                    .frame(width: 44, height: 44)
                    .background(Color.joltCardBackground)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Status Segment
    
    private var statusSegment: some View {
        HStack(spacing: 0) {
            ForEach(StatusFilter.allCases, id: \.self) { status in
                let count = getCount(for: status)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = status
                        if status == .starred {
                            selectedType = nil
                            selectedCollection = nil
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(status.title)
                            .font(.system(size: 14, weight: selectedStatus == status ? .semibold : .regular))
                        Text("\(count)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(selectedStatus == status ? .black : .joltMutedForeground)
                    }
                    .foregroundColor(selectedStatus == status ? .black : .joltForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedStatus == status ? Color.joltYellow : Color.clear)
                }
            }
        }
        .background(Color.joltCardBackground)
        .cornerRadius(12)
    }
    
    private func getCount(for status: StatusFilter) -> Int {
        switch status {
        case .all: return statusCounts.all
        case .unread: return statusCounts.unread
        case .read: return statusCounts.read
        case .starred: return statusCounts.starred
        }
    }
    
    // MARK: - Quick Access Section
    
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("library.quickAccess".localized)
                .font(.iosTitle3)
                .foregroundColor(.joltForeground)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Starred Quick Access
                    QuickAccessCard(
                        icon: "star.fill",
                        title: "library.filter.starred".localized,
                        count: statusCounts.starred,
                        color: "#FFD60A",
                        isSelected: selectedStatus == .starred
                    ) {
                        withAnimation {
                            selectedStatus = .starred
                            selectedType = nil
                        }
                    }
                    
                    // Type-based Quick Access
                    ForEach(quickAccessTypes, id: \.self) { type in
                        QuickAccessCard(
                            icon: type.icon,
                            title: type.displayName,
                            count: typeCounts[type] ?? 0,
                            color: type.color,
                            isSelected: selectedType == type
                        ) {
                            withAnimation {
                                if selectedType == type {
                                    selectedType = nil
                                } else {
                                    selectedType = type
                                    selectedStatus = .all
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var quickAccessTypes: [BookmarkType] {
        // Only show types that have content
        [.article, .video, .social, .audio, .code, .design]
            .filter { (typeCounts[$0] ?? 0) > 0 }
    }
    
    // MARK: - Collections Section
    
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("library.collections".localized)
                    .font(.iosTitle3)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("library.new".localized)
                    }
                    .font(.iosFootnote)
                    .foregroundColor(.joltYellow)
                }
            }
            
            VStack(spacing: 8) {
                // Inbox (Uncategorized)
                CollectionRow(
                    icon: "tray.fill",
                    name: "collectionPicker.inbox".localized,
                    count: inboxCount,
                    color: "#8E8E93",
                    isSelected: selectedCollection == nil && selectedType == nil && selectedStatus == .all
                ) {
                    // Already showing all
                }
                
                // User Collections
                ForEach(allCollections) { collection in
                    CollectionRow(
                        icon: collection.icon,
                        name: collection.name,
                        count: collection.bookmarks.count,
                        color: collection.color,
                        isSelected: selectedCollection?.id == collection.id
                    ) {
                        navigationPath.append(collection)
                    }
                    .contextMenu {
                        Button {
                            collectionToEdit = collection
                        } label: {
                            Label("common.edit".localized, systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            collectionToDelete = collection
                            showDeleteCollectionAlert = true
                        } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.joltCardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Bookmarks Section
    
    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                let title = getSectionTitle()
                Text(title)
                    .font(.iosTitle3)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Text("library.items".localized(with: filteredBookmarks.count))
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
            }
            
            if filteredBookmarks.isEmpty {
                emptyState
            } else {
                if viewMode == .list {
                    bookmarkListView
                } else {
                    bookmarkGridView
                }
            }
        }
    }
    
    private func getSectionTitle() -> String {
        if let type = selectedType {
            return type.displayName
        }
        if selectedStatus == .starred {
            return "library.filter.starred".localized
        }
        if selectedStatus == .unread {
            return "library.filter.unread".localized
        }
        if selectedStatus == .read {
            return "library.filter.read".localized
        }
        return "library.allBookmarks".localized
    }
    
    private var bookmarkListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredBookmarks) { bookmark in
                LibraryBookmarkCard(
                    bookmark: bookmark,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedBookmarks.contains(bookmark.id),
                    onTap: {
                        if isSelectionMode {
                            toggleSelection(bookmark)
                        } else {
                            selectedBookmark = bookmark
                        }
                    },
                    onStar: {
                        toggleStar(bookmark)
                    },
                    onDelete: {
                        deleteBookmark(bookmark)
                    },
                    onMove: {
                        // Handle move
                    }
                )
            }
        }
    }
    
    private var bookmarkGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredBookmarks) { bookmark in
                LibraryGridCard(
                    bookmark: bookmark,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedBookmarks.contains(bookmark.id),
                    onTap: {
                        if isSelectionMode {
                            toggleSelection(bookmark)
                        } else {
                            selectedBookmark = bookmark
                        }
                    },
                    onStar: {
                        toggleStar(bookmark)
                    }
                )
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: getEmptyStateIcon())
                .font(.system(size: 48))
                .foregroundColor(.joltMutedForeground)
            
            Text(getEmptyStateTitle())
                .font(.iosHeadline)
                .foregroundColor(.joltForeground)
            
            Text(getEmptyStateSubtitle())
                .font(.iosSubheadline)
                .foregroundColor(.joltMutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func getEmptyStateIcon() -> String {
        if !searchText.isEmpty { return "magnifyingglass" }
        if selectedStatus == .starred { return "star" }
        if selectedType != nil { return selectedType!.icon }
        return "books.vertical"
    }
    
    private func getEmptyStateTitle() -> String {
        if !searchText.isEmpty { return "empty.search.title".localized }
        if selectedStatus == .starred { return "library.empty.starred".localized }
        if selectedType != nil { return "library.empty.type".localized(with: selectedType!.displayName) }
        return "empty.library.title".localized
    }
    
    private func getEmptyStateSubtitle() -> String {
        if !searchText.isEmpty { return "empty.search.subtitle".localized }
        if selectedStatus == .starred { return "library.empty.starredHint".localized }
        return "empty.library.subtitle".localized
    }
    
    // MARK: - Sort Options Sheet
    
    private var sortOptionsSheet: some View {
        NavigationStack {
            List {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        showSortSheet = false
                    } label: {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.joltMutedForeground)
                                .frame(width: 24)
                            
                            Text(option.title)
                                .foregroundColor(.joltForeground)
                            
                            Spacer()
                            
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.joltYellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("library.sort.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        showSortSheet = false
                    }
                    .foregroundColor(.joltYellow)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Batch Action Bar
    
    private var batchActionBar: some View {
        HStack(spacing: 32) {
            BatchActionButton(icon: "trash", label: "common.delete".localized, color: .red) {
                if !selectedBookmarks.isEmpty {
                    showBulkDeleteAlert = true
                }
            }
            .disabled(selectedBookmarks.isEmpty)
            
            BatchActionButton(icon: "folder", label: "library.action.move".localized, color: .joltYellow) {
                if !selectedBookmarks.isEmpty {
                    showBulkCollectionPicker = true
                }
            }
            .disabled(selectedBookmarks.isEmpty)
            
            BatchActionButton(icon: "star.fill", label: "library.action.star".localized, color: .orange) {
                starSelectedBookmarks()
            }
            .disabled(selectedBookmarks.isEmpty)
            
            BatchActionButton(icon: "checkmark.circle", label: "common.archive".localized, color: .green) {
                archiveSelectedBookmarks()
            }
            .disabled(selectedBookmarks.isEmpty)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.joltCardBackground)
    }
    
    // MARK: - Actions
    
    private func toggleSelectionMode() {
        withAnimation {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedBookmarks.removeAll()
            }
        }
    }
    
    private func toggleSelection(_ bookmark: Bookmark) {
        if selectedBookmarks.contains(bookmark.id) {
            selectedBookmarks.remove(bookmark.id)
        } else {
            selectedBookmarks.insert(bookmark.id)
        }
    }
    
    private func selectAll() {
        if selectedBookmarks.count == filteredBookmarks.count {
            selectedBookmarks.removeAll()
        } else {
            selectedBookmarks = Set(filteredBookmarks.map { $0.id })
        }
    }
    
    private func toggleStar(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.isStarred = !(bookmark.isStarred ?? false)
        }
        try? modelContext.save()
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
        try? modelContext.save()
    }
    
    private func deleteSelectedBookmarks() {
        for id in selectedBookmarks {
            if let bookmark = allBookmarks.first(where: { $0.id == id }) {
                modelContext.delete(bookmark)
            }
        }
        try? modelContext.save()
        selectedBookmarks.removeAll()
        isSelectionMode = false
    }
    
    private func moveSelectedBookmarks(to collection: Collection?) {
        for id in selectedBookmarks {
            if let bookmark = allBookmarks.first(where: { $0.id == id }) {
                bookmark.collection = collection
            }
        }
        try? modelContext.save()
        selectedBookmarks.removeAll()
        isSelectionMode = false
    }
    
    private func starSelectedBookmarks() {
        for id in selectedBookmarks {
            if let bookmark = allBookmarks.first(where: { $0.id == id }) {
                bookmark.isStarred = true
            }
        }
        try? modelContext.save()
        selectedBookmarks.removeAll()
        isSelectionMode = false
    }
    
    private func archiveSelectedBookmarks() {
        for id in selectedBookmarks {
            if let bookmark = allBookmarks.first(where: { $0.id == id }) {
                bookmark.status = .archived
                bookmark.readAt = Date()
            }
        }
        try? modelContext.save()
        selectedBookmarks.removeAll()
        isSelectionMode = false
    }
    
    private func deleteCollectionOnly(_ collection: Collection) {
        for bookmark in collection.bookmarks {
            bookmark.collection = nil
        }
        modelContext.delete(collection)
        try? modelContext.save()
        collectionToDelete = nil
    }
    
    private func deleteCollectionWithBookmarks(_ collection: Collection) {
        for bookmark in collection.bookmarks {
            modelContext.delete(bookmark)
        }
        modelContext.delete(collection)
        try? modelContext.save()
        collectionToDelete = nil
    }
}

// MARK: - Supporting Views

struct QuickAccessCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: color).opacity(isSelected ? 1 : 0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : Color(hex: color))
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.joltForeground)
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.joltMutedForeground)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(isSelected ? Color.joltCardBackground : Color.clear)
            .cornerRadius(12)
        }
    }
}

struct CollectionRow: View {
    let icon: String
    let name: String
    let count: Int
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: color).opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: color))
                }
                
                Text(name)
                    .font(.iosBody)
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Text("\(count)")
                    .font(.iosFootnote)
                    .foregroundColor(.joltMutedForeground)
                
                Image(systemName: "chevron.right")
                    .font(.iosCaption1)
                    .foregroundColor(.joltMutedForeground)
            }
            .padding(.vertical, 4)
        }
    }
}

struct LibraryBookmarkCard: View {
    let bookmark: Bookmark
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onStar: () -> Void
    let onDelete: () -> Void
    let onMove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection Circle
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .joltYellow : .joltMutedForeground)
                        .accessibilityHidden(true) // Part of main label
                }
                
                // Thumbnail
                ZStack {
                    if let coverImage = bookmark.coverImage, let url = URL(string: coverImage) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            thumbnailPlaceholder
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                    
                    // Star Badge
                    if bookmark.isStarred == true {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .cornerRadius(10)
                .clipped()
                .accessibilityHidden(true) // Decorative
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(bookmark.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                    
                    // Domain + Type
                    HStack(spacing: 6) {
                        if let platformIcon = bookmark.platformIcon {
                            Image(systemName: platformIcon)
                                .font(.system(size: 11))
                        }
                        Text(bookmark.domain)
                            .font(.system(size: 12))
                        
                        Text("•")
                        
                        Text(bookmark.type.displayName)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.joltMutedForeground)
                    
                    // Progress Bar + Time
                    HStack(spacing: 8) {
                        if let progress = bookmark.lastScrollPercentage, progress > 0 {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .joltYellow))
                                .frame(width: 60)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.joltMutedForeground)
                        }
                        
                        if bookmark.readingTimeMinutes > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("time.minutes".localized(with: bookmark.readingTimeMinutes))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.joltMutedForeground)
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        if bookmark.status == .archived {
                            Text("library.read".localized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.joltCardBackground)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        // MARK: Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelectionMode ? (isSelected ? "Seçimi kaldırmak için çift dokunun" : "Seçmek için çift dokunun") : "Okuyucuda açmak için çift dokunun")
        .accessibilityAddTraits(isSelectionMode && isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityActions {
            Button(bookmark.isStarred == true ? A11y.Reader.unstarButton : A11y.Reader.starButton) { onStar() }
            Button(A11y.Reader.collectionButton) { onMove() }
            Button(A11y.Common.deleteButton) { onDelete() }
        }
        .contextMenu {
            Button {
                onStar()
            } label: {
                Label((bookmark.isStarred == true) ? "library.action.unstar".localized : "library.action.star".localized, systemImage: (bookmark.isStarred == true) ? "star.slash" : "star")
            }
            
            Button {
                onMove()
            } label: {
                Label("reader.moveToCollection".localized, systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("common.delete".localized, systemImage: "trash")
            }
        }
    }
    
    private var accessibilityLabel: String {
        var label = A11y.Library.bookmarkRow(
            title: bookmark.title,
            isRead: bookmark.status == .archived,
            readingTime: bookmark.readingTimeMinutes
        )
        if bookmark.isStarred == true {
            label += " Favorilerde."
        }
        if let progress = bookmark.lastScrollPercentage, progress > 0 {
            label += " Yüzde \(Int(progress * 100)) ilerleme."
        }
        if isSelectionMode && isSelected {
            label += " Seçildi."
        }
        return label
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.joltMuted
            Image(systemName: bookmark.type.icon)
                .font(.system(size: 20))
                .foregroundColor(.joltMutedForeground)
        }
    }
}

struct LibraryGridCard: View {
    let bookmark: Bookmark
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onStar: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .topTrailing) {
                    if let coverImage = bookmark.coverImage, let url = URL(string: coverImage) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            gridThumbnailPlaceholder
                        }
                    } else {
                        gridThumbnailPlaceholder
                    }
                    
                    // Selection/Star overlay
                    VStack {
                        HStack {
                            if isSelectionMode {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(isSelected ? .joltYellow : .white)
                                    .shadow(radius: 2)
                                    .padding(8)
                            }
                            
                            Spacer()
                            
                            if bookmark.isStarred == true {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                    .padding(8)
                            }
                        }
                        Spacer()
                        
                        // Type Badge
                        HStack {
                            Spacer()
                            Text(bookmark.type.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                                .padding(8)
                        }
                    }
                }
                .frame(height: 100)
                .cornerRadius(10)
                .clipped()
                
                // Title
                Text(bookmark.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.joltForeground)
                    .lineLimit(2)
                
                // Info Row
                HStack {
                    Text(bookmark.domain)
                        .font(.system(size: 11))
                        .foregroundColor(.joltMutedForeground)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if bookmark.readingTimeMinutes > 0 {
                        Text("widget.focus.minutesRead".localized(with: bookmark.readingTimeMinutes))
                            .font(.system(size: 11))
                            .foregroundColor(.joltMutedForeground)
                    }
                }
                
                // Progress
                if let progress = bookmark.lastScrollPercentage, progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .joltYellow))
                }
            }
            .padding(10)
            .background(Color.joltCardBackground)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    
    private var gridThumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: bookmark.type.color).opacity(0.3), Color.joltMuted],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: bookmark.type.icon)
                .font(.system(size: 28))
                .foregroundColor(Color(hex: bookmark.type.color))
        }
    }
}

struct BatchActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(isEnabled ? color : color.opacity(0.4))
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Bookmark.self, Collection.self], inMemory: true)
}
