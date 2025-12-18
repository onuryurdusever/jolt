//
//  HistoryView.swift
//  jolt
//
//  Created by Onur Yurdusever on 7.12.2025.
//  v2.1 - Timeline-based History View
//

import SwiftUI
import SwiftData
import RevenueCat
import RevenueCatUI

@MainActor
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    @Query(sort: \Bookmark.archivedAt, order: .reverse) private var allBookmarks: [Bookmark]
    @Query(sort: \JoltCollection.createdAt, order: .reverse) private var collections: [JoltCollection]
    
    // Callback for iPad/Mac sidebar toggle
    var onToggleSidebar: (() -> Void)? = nil
    var isSidebarVisible: Bool = false
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedBookmark: Bookmark?
    @State private var selectedCollection: JoltCollection?
    @State private var showShareSheet = false
    @State private var bookmarkToShare: Bookmark?
    @State private var showNewCollectionSheet = false
    
    // MARK: - Filter Enum
    
    enum HistoryFilter: String, CaseIterable {
        case all
        case favorites
        case twitter
        case instagram
        case web
        case collections
        case expired
        
        var title: String {
            switch self {
            case .all: return "history.filter.all".localized
            case .favorites: return "history.filter.favorites".localized
            case .twitter: return "X"
            case .instagram: return "Instagram"
            case .web: return "Web"
            case .collections: return "history.filter.collections".localized
            case .expired: return "history.filter.expired".localized
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "clock.arrow.circlepath"
            case .favorites: return "star.fill"
            case .twitter: return "at"
            case .instagram: return "camera"
            case .web: return "globe"
            case .collections: return "folder.fill"
            case .expired: return "flame.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .joltYellow
            case .favorites: return .yellow
            case .twitter: return .white
            case .instagram: return .pink
            case .web: return .blue
            case .collections: return Color.joltGreen
            case .expired: return .orange
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Tamamlanmış içerikler (completed veya archived)
    private var completedBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .completed || $0.status == .archived }
    }
    
    /// Süresi dolmuş içerikler (expired)
    private var expiredBookmarks: [Bookmark] {
        allBookmarks.filter { $0.status == .expired }
    }
    
    /// Filtrelenmiş içerikler
    private var filteredBookmarks: [Bookmark] {
        var bookmarks: [Bookmark]
        
        switch selectedFilter {
        case .all:
            bookmarks = completedBookmarks
        case .favorites:
            bookmarks = completedBookmarks.filter { $0.isStarred == true }
        case .twitter:
            bookmarks = completedBookmarks.filter { isTwitterDomain($0.domain) }
        case .instagram:
            bookmarks = completedBookmarks.filter { isInstagramDomain($0.domain) }
        case .web:
            bookmarks = completedBookmarks.filter { !isTwitterDomain($0.domain) && !isInstagramDomain($0.domain) }
        case .collections:
            bookmarks = [] // Handled by collectionsGrid
        case .expired:
            bookmarks = expiredBookmarks
        }
        
        // Search filter
        if !searchText.isEmpty {
            bookmarks = bookmarks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.domain.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return bookmarks
    }
    
    /// Timeline grupları
    private var timelineGroups: [(title: String, bookmarks: [Bookmark])] {
        let calendar = Calendar.current
        let now = Date()
        
        var today: [Bookmark] = []
        var yesterday: [Bookmark] = []
        var thisWeek: [Bookmark] = []
        var older: [Bookmark] = []
        
        for bookmark in filteredBookmarks {
            let completedDate = bookmark.archivedAt ?? bookmark.createdAt
            
            if calendar.isDateInToday(completedDate) {
                today.append(bookmark)
            } else if calendar.isDateInYesterday(completedDate) {
                yesterday.append(bookmark)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      completedDate >= weekAgo {
                thisWeek.append(bookmark)
            } else {
                older.append(bookmark)
            }
        }
        
        var groups: [(title: String, bookmarks: [Bookmark])] = []
        
        if !today.isEmpty {
            groups.append(("history.today".localized, today))
        }
        if !yesterday.isEmpty {
            groups.append(("history.yesterday".localized, yesterday))
        }
        if !thisWeek.isEmpty {
            groups.append(("history.thisWeek".localized, thisWeek))
        }
        if !older.isEmpty {
            groups.append(("history.older".localized, older))
        }
        
        return groups
    }
    
    // MARK: - Helper Functions
    
    private func isTwitterDomain(_ domain: String) -> Bool {
        let d = domain.lowercased()
        return d.contains("twitter.com") || d.contains("x.com") || d.contains("t.co")
    }
    
    private func isInstagramDomain(_ domain: String) -> Bool {
        let d = domain.lowercased()
        return d.contains("instagram.com") || d.contains("instagr.am")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    
                    // Filter Chips
                    filterChips
                        .padding(.bottom, 16)
                    
                    // Timeline Content
                    if selectedFilter == .collections {
                        collectionsGrid
                    } else if filteredBookmarks.isEmpty {
                        emptyState
                            .frame(maxHeight: .infinity)
                    } else {
                        timelineList
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true)
            }
            .navigationDestination(item: $selectedBookmark) { bookmark in
                ReaderView(bookmark: bookmark, isArchived: true)
            }
            .sheet(isPresented: $showNewCollectionSheet) {
                NewCollectionSheet()
            }
            .navigationDestination(item: $selectedCollection) { collection in
                DetailedCollectionView(collection: collection)
            }
        }
    }
    
    private var collectionsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // New Collection Button
                Button {
                    showNewCollectionSheet = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color.joltGreen)
                        Text("history.collections.add".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.joltForeground)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Color.joltCardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.joltGreen.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                }
                
                // Existing Collections
                ForEach(collections) { collection in
                    Button {
                        selectedCollection = collection
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(collection.emoji ?? "📁")
                                .font(.system(size: 32))
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.joltForeground)
                                    .lineLimit(1)
                                
                                Text("history.collections.itemCount".localized(with: collection.bookmarks?.count ?? 0))
                                    .font(.system(size: 12))
                                    .foregroundColor(.joltMutedForeground)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                        .background(Color.joltCardBackground)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Sidebar Toggle (iPad/Mac)
            if let toggle = onToggleSidebar, !isSidebarVisible {
                Button {
                    toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                }
                .padding(.trailing, 12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("history.title".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.joltMutedForeground)
                    .tracking(3)
                
                Text("history.subtitle".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.joltForeground)
            }
            
            Spacer()
            
            // Stats Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(completedBookmarks.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.joltYellow)
                Text("history.completed".localized)
                    .font(.system(size: 10))
                    .foregroundColor(.joltMutedForeground)
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.joltMutedForeground)
            
            TextField("history.search.placeholder".localized, text: $searchText)
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
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: getFilterCount(filter)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if filter == .collections && !subManager.isPro {
                                showPaywall = true
                            } else {
                                selectedFilter = filter
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func getFilterCount(_ filter: HistoryFilter) -> Int {
        switch filter {
        case .all: return completedBookmarks.count
        case .favorites: return completedBookmarks.filter { $0.isStarred == true }.count
        case .twitter: return completedBookmarks.filter { isTwitterDomain($0.domain) }.count
        case .instagram: return completedBookmarks.filter { isInstagramDomain($0.domain) }.count
        case .web: return completedBookmarks.filter { !isTwitterDomain($0.domain) && !isInstagramDomain($0.domain) }.count
        case .collections: return collections.count
        case .expired: return expiredBookmarks.count
        }
    }
    
    // MARK: - Timeline List
    
    private var timelineList: some View {
        List {
            ForEach(timelineGroups, id: \.title) { group in
                Section {
                    ForEach(group.bookmarks) { bookmark in
                        if selectedFilter == .expired {
                            ExpiredItemRow(bookmark: bookmark)
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            HistoryItemRow(
                                bookmark: bookmark,
                                onTap: { selectedBookmark = bookmark },
                                onShare: {
                                    bookmarkToShare = bookmark
                                    showShareSheet = true
                                },
                                onDelete: { deleteBookmark(bookmark) },
                                collections: collections,
                                onAssign: { col in assignToCollection(bookmark, col) },
                                onRemove: { removeFromCollection(bookmark) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                } header: {
                    Text(group.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .expired ? "flame" : "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.joltMutedForeground.opacity(0.5))
            
            Text(selectedFilter == .expired ? "history.empty.expired".localized : "history.empty.title".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.joltForeground)
            
            Text(selectedFilter == .expired ? "history.empty.expiredSubtitle".localized : "history.empty.subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.joltMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Actions
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        withAnimation {
            modelContext.delete(bookmark)
            try? modelContext.save()
        }
    }
    
    private func assignToCollection(_ bookmark: Bookmark, _ collection: JoltCollection) {
        withAnimation {
            bookmark.collection = collection
            try? modelContext.save()
        }
    }
    
    private func removeFromCollection(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.collection = nil
            try? modelContext.save()
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let filter: HistoryView.HistoryFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12))
                
                Text(filter.title)
                    .font(.system(size: 13, weight: .medium))
                
                if count > 0 && !isSelected {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.joltMutedForeground)
                }
                
                if filter == .collections && !SubscriptionManager.shared.isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }
            .foregroundColor(isSelected ? .black : .joltForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? filter.color : Color.joltCardBackground)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let collections: [JoltCollection]
    let onAssign: (JoltCollection) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Platform Icon or Thumbnail
                platformIcon
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(bookmark.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                    
                    // Meta Info
                    HStack(spacing: 6) {
                        Text(bookmark.domain.replacingOccurrences(of: "www.", with: ""))
                            .font(.system(size: 12))
                            .foregroundColor(.joltMutedForeground)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.joltMutedForeground.opacity(0.5))
                        
                        Text("history.readTime".localized(with: bookmark.readingTimeMinutes))
                            .font(.system(size: 12))
                            .foregroundColor(.joltMutedForeground)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.joltMutedForeground.opacity(0.5))
                        
                        Text(completedTimeText)
                            .font(.system(size: 12))
                            .foregroundColor(.joltMutedForeground)
                    }
                }
                
                Spacer(minLength: 8)
                
                // Completed Check
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            .padding(12)
            .background(Color.joltCardBackground)
            .cornerRadius(12)
            .contextMenu {
                Menu {
                    ForEach(collections) { collection in
                        Button {
                            onAssign(collection)
                        } label: {
                            Label(collection.name, systemImage: "folder")
                        }
                    }
                    
                    if bookmark.collection != nil {
                        Divider()
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("history.collections.remove".localized, systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Label("history.collections.assign".localized, systemImage: "folder.badge.plus")
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("common.delete".localized, systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onShare()
            } label: {
                Label("common.share".localized, systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
    }
    
    private var platformIcon: some View {
        Group {
            if let coverImage = bookmark.coverImage, let url = URL(string: coverImage) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultIcon
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
                .clipped()
            } else {
                defaultIcon
            }
        }
    }
    
    private var defaultIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(platformColor.opacity(0.15))
                .frame(width: 48, height: 48)
            
            Image(systemName: platformIconName)
                .font(.system(size: 20))
                .foregroundColor(platformColor)
        }
    }
    
    private var platformIconName: String {
        let domain = bookmark.domain.lowercased()
        if domain.contains("twitter.com") || domain.contains("x.com") {
            return "at"
        } else if domain.contains("instagram.com") {
            return "camera"
        } else if domain.contains("youtube.com") {
            return "play.rectangle.fill"
        } else if domain.contains("github.com") {
            return "chevron.left.forwardslash.chevron.right"
        } else if domain.contains("medium.com") {
            return "text.quote"
        } else {
            return bookmark.type.icon
        }
    }
    
    private var platformColor: Color {
        let domain = bookmark.domain.lowercased()
        if domain.contains("twitter.com") || domain.contains("x.com") {
            return .white
        } else if domain.contains("instagram.com") {
            return .pink
        } else if domain.contains("youtube.com") {
            return .red
        } else if domain.contains("github.com") {
            return .purple
        } else if domain.contains("medium.com") {
            return .green
        } else {
            return .joltYellow
        }
    }
    
    private var completedTimeText: String {
        guard let completedAt = bookmark.archivedAt else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "history.completedAt".localized(with: formatter.string(from: completedAt))
    }
}

// MARK: - Expired Item Row (Ghost/Graveyard)

struct ExpiredItemRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            // Flame Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange.opacity(0.6))
            }
            
            // Content (Struck-through)
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.joltMutedForeground.opacity(0.5))
                    .strikethrough(true, color: .joltMutedForeground.opacity(0.3))
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(bookmark.domain.replacingOccurrences(of: "www.", with: ""))
                        .font(.system(size: 12))
                    
                    Text("•")
                        .font(.system(size: 10))
                    
                    Text("history.expired".localized)
                }
                .foregroundColor(.joltMutedForeground.opacity(0.4))
            }
            
            Spacer(minLength: 8)
            
            // Expired Badge
            Image(systemName: "xmark.circle")
                .font(.system(size: 18))
                .foregroundColor(.orange.opacity(0.5))
        }
        .padding(12)
        .background(Color.joltCardBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .modelContainer(for: [Bookmark.self], inMemory: true)
}
