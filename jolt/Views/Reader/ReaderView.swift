//
//  ReaderView.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//  Redesigned: 4.12.2025 - Rich Header, Platform Metadata, Enhanced Article Reader
//

import SwiftUI
import SwiftData
import WebKit
import PDFKit

// MARK: - Reader Settings

struct ReaderSettings {
    enum Theme: String, CaseIterable {
        case dark = "Dark"
        case sepia = "Sepia"
        case light = "Light"
        
        var backgroundColor: Color {
            switch self {
            case .dark: return Color(hex: "#141414")
            case .sepia: return Color(hex: "#F4ECD8")
            case .light: return Color(hex: "#FFFFFF")
            }
        }
        
        var textColor: Color {
            switch self {
            case .dark: return Color.white.opacity(0.9)
            case .sepia: return Color(hex: "#5B4636")
            case .light: return Color(hex: "#1C1C1E")
            }
        }
        
        var linkColor: String {
            switch self {
            case .dark: return "#CCFF00"
            case .sepia: return "#8B6914"
            case .light: return "#007AFF"
            }
        }
    }
}

// MARK: - Main Reader View

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark
    var isArchived: Bool = false
    var onJoltCompleted: ((Bookmark) -> Void)?
    
    // UI State
    @State private var dragOffset: CGFloat = 0

    @State private var showSettings = false
    @State private var useReaderMode = true // For webview toggle
    @State private var scrollProgress: Double = 0
    
    // Reader Settings (persisted)
    @AppStorage("readerFontSize") private var fontSize: Double = 18
    @AppStorage("readerTheme") private var themeRaw: String = "dark"
    @AppStorage("readerLineHeight") private var lineHeight: Double = 1.6
    
    private var theme: ReaderSettings.Theme {
        ReaderSettings.Theme(rawValue: themeRaw) ?? .dark
    }
    
    var body: some View {
        ZStack {
            Color.joltBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Rich Header
                ReaderHeaderView(
                    bookmark: bookmark,
                    scrollProgress: scrollProgress
                )
                
                // Platform Metadata Bar (conditional)
                if hasPlatformMetadata {
                    PlatformMetadataBar(bookmark: bookmark)
                }
                
                // Content based on type
                contentView
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        } else {
                            withAnimation {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Domain badge
                HStack(spacing: 4) {
                    if let platformIcon = bookmark.platformIcon {
                        Image(systemName: platformIcon)
                            .font(.system(size: 10))
                    }
                    Text(bookmark.domain)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.joltMutedForeground)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Reader Mode Toggle (only for webview with contentHTML)
                    if bookmark.type != .article && bookmark.contentHTML != nil {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                useReaderMode.toggle()
                            }
                        } label: {
                            Image(systemName: useReaderMode ? "doc.plaintext.fill" : "globe")
                                .font(.system(size: 16))
                                .foregroundColor(useReaderMode ? .joltYellow : .joltMutedForeground)
                        }
                    }
                    
                    // Settings (article mode only)
                    if shouldShowSettings {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 16))
                                .foregroundColor(.joltMutedForeground)
                        }
                    }
                    
                    // Menu
                    Menu {

                        
                        if let url = URL(string: bookmark.originalURL) {
                            ShareLink(item: url) {
                                Label("common.share".localized, systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            UIPasteboard.general.string = bookmark.originalURL
                        } label: {
                            Label("reader.copyLink".localized, systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.joltYellow)
                    }
                }
            }
        }

        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(
                fontSize: $fontSize,
                themeRaw: $themeRaw,
                lineHeight: $lineHeight
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasPlatformMetadata: Bool {
        guard let metadata = bookmark.metadata else { return false }
        // Check if we have meaningful platform-specific data
        return metadata["stars"] != nil ||
               metadata["author_name"] != nil ||
               metadata["duration_iso"] != nil ||
               metadata["artist"] != nil
    }
    
    private var shouldShowSettings: Bool {
        // Show settings for article mode or reader mode
        bookmark.type == .article || (useReaderMode && bookmark.contentHTML != nil)
    }
    
    /// Check if we have valid parsed content (not empty, not too short)
    private var hasValidContent: Bool {
        guard let html = bookmark.contentHTML else { return false }
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        // Minimum 100 chars to be considered valid (filters out error messages)
        return !trimmed.isEmpty && trimmed.count > 100
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if bookmark.isPDF {
            PDFReaderView(
                url: URL(string: bookmark.originalURL),
                bookmark: bookmark,
                scrollProgress: $scrollProgress,
                onJolt: joltAction,
                isArchived: isArchived
            )
        } else if bookmark.requiresWebView || !hasValidContent {
            // Protected, paywalled, low-confidence, OR no valid content → WebView
            VStack(spacing: 0) {
                // Show appropriate info banner
                if bookmark.showProtectedBadge || bookmark.showPaywallBadge {
                    ContentStatusBanner(bookmark: bookmark)
                } else if !hasValidContent {
                    // Fallback banner: showing original site because parsing failed
                    ContentFallbackBanner()
                }
                
                WebReaderView(
                    url: bookmark.originalURL,
                    bookmark: bookmark,
                    scrollProgress: $scrollProgress,
                    onJolt: joltAction,
                    isArchived: isArchived
                )
            }
        } else {
            switch bookmark.type {
            case .article:
                EnhancedArticleReaderView(
                    bookmark: bookmark,
                    fontSize: fontSize,
                    theme: theme,
                    lineHeight: lineHeight,
                    scrollProgress: $scrollProgress,
                    onJolt: joltAction,
                    isArchived: isArchived
                )
            case .video, .social, .audio, .code, .product, .map, .design, .webview:
                // For non-article types: use reader mode if available and enabled
                if useReaderMode && hasValidContent {
                    EnhancedArticleReaderView(
                        bookmark: bookmark,
                        fontSize: fontSize,
                        theme: theme,
                        lineHeight: lineHeight,
                        scrollProgress: $scrollProgress,
                        onJolt: joltAction,
                        isArchived: isArchived
                    )
                } else {
                    WebReaderView(
                        url: bookmark.originalURL,
                        bookmark: bookmark,
                        scrollProgress: $scrollProgress,
                        onJolt: joltAction,
                        isArchived: isArchived
                    )
                }
            case .pdf:
                PDFReaderView(
                    url: URL(string: bookmark.originalURL),
                    bookmark: bookmark,
                    scrollProgress: $scrollProgress,
                    onJolt: joltAction,
                    isArchived: isArchived
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func joltAction() {
        print("⚡ Jolting bookmark: \(bookmark.title)")
        updateStreak()
        
        // Remove from Spotlight
        SpotlightService.shared.removeBookmark(bookmark)
        
        if let onJoltCompleted = onJoltCompleted {
            onJoltCompleted(bookmark)
        } else {
            bookmark.status = .archived
            bookmark.readAt = Date()
            try? modelContext.save()
            
            // Full widget update to get next bookmark
            WidgetDataService.shared.updateWidgetData(modelContext: modelContext)
            
            dismiss()
        }
    }
    
    private func updateStreak() {
        @AppStorage("currentStreak") var currentStreak = 0
        @AppStorage("previousStreak") var previousStreak = 0
        @AppStorage("lastJoltDate") var lastJoltDateString = ""
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastJoltDate = ISO8601DateFormatter().date(from: lastJoltDateString) {
            let lastJoltDay = calendar.startOfDay(for: lastJoltDate)
            let daysDifference = calendar.dateComponents([.day], from: lastJoltDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                return
            } else if daysDifference == 1 {
                currentStreak += 1
                // Update widget streak
                WidgetDataService.shared.updateStreak(currentStreak)
            } else {
                previousStreak = currentStreak
                currentStreak = 1
                // Update widget streak
                WidgetDataService.shared.updateStreak(currentStreak)
            }
        } else {
            currentStreak = 1
            WidgetDataService.shared.updateStreak(currentStreak)
        }
        
        lastJoltDateString = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Reader Header View (Compact)

struct ReaderHeaderView: View {
    let bookmark: Bookmark
    let scrollProgress: Double
    
    private var remainingMinutes: Int {
        let remaining = Double(bookmark.readingTimeMinutes) * (1.0 - scrollProgress)
        return max(1, Int(remaining.rounded()))
    }
    
    private var hasResumePoint: Bool {
        (bookmark.lastScrollPercentage ?? 0) > 0.05
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact Header Row: Thumbnail + Title + Meta
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail (60x60)
                if let coverURL = bookmark.coverImage, !coverURL.isEmpty {
                    CachedAsyncImage(
                        url: URL(string: coverURL),
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        },
                        placeholder: {
                            thumbnailPlaceholder
                        }
                    )
                } else {
                    thumbnailPlaceholder
                }
                
                // Title + Meta
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(bookmark.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.joltForeground)
                        .lineLimit(2)
                    
                    // Meta row: type badge + reading time + resume
                    HStack(spacing: 8) {
                        // Type badge (compact)
                        HStack(spacing: 3) {
                            Image(systemName: bookmark.type.icon)
                                .font(.system(size: 9))
                            Text(bookmark.type.displayName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color(hex: bookmark.type.color))
                        
                        // Separator
                        Circle()
                            .fill(Color.joltMutedForeground.opacity(0.5))
                            .frame(width: 3, height: 3)
                        
                        // Reading time / Remaining
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            if scrollProgress > 0.05 {
                                Text("reader.minutesLeft".localized(with: remainingMinutes))
                            } else {
                                Text("reader.minutesRead".localized(with: bookmark.readingTimeMinutes))
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.joltMutedForeground)
                        
                        // Resume badge (if applicable)
                        if hasResumePoint && scrollProgress < 0.05 {
                            HStack(spacing: 2) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 8))
                                Text("\(Int((bookmark.lastScrollPercentage ?? 0) * 100))%")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.joltYellow)
                        }
                    }
        
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // User Note (if present) - single line with expand option
            if let note = bookmark.userNote, !note.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundColor(.joltYellow.opacity(0.6))
                    
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundColor(.joltMutedForeground)
                        .italic()
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.joltMuted.opacity(0.3))
                .cornerRadius(6)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
        .background(Color.joltBackground)
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.joltMuted)
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: bookmark.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: bookmark.type.color).opacity(0.6))
            )
    }
}

// MARK: - Platform Metadata Bar

struct PlatformMetadataBar: View {
    let bookmark: Bookmark
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // YouTube / Video
                if let authorName = bookmark.metadata?["author_name"] {
                    metadataChip(icon: "person.fill", text: authorName)
                }
                
                if let durationISO = bookmark.metadata?["duration_iso"] {
                    let formatted = formatDuration(durationISO)
                    if !formatted.isEmpty {
                        metadataChip(icon: "play.fill", text: formatted)
                    }
                }
                
                // GitHub
                if let stars = bookmark.metadata?["stars"] {
                    metadataChip(icon: "star.fill", text: stars, color: "#FFD700")
                }
                
                if let forks = bookmark.metadata?["forks"] {
                    metadataChip(icon: "tuningfork", text: forks)
                }
                
                if let language = bookmark.metadata?["language"], !language.isEmpty {
                    languageBadge(language)
                }
                
                // Spotify / Audio
                if let artist = bookmark.metadata?["artist"] {
                    metadataChip(icon: "music.note", text: artist, color: "#1DB954")
                }
                
                // Twitter / Social
                if let handle = bookmark.metadata?["author_handle"] {
                    metadataChip(icon: "at", text: handle, color: "#1DA1F2")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.joltCardBackground)
    }
    
    private func metadataChip(icon: String, text: String, color: String = "#8E8E93") -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: color))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.joltForeground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.joltMuted)
        .cornerRadius(8)
    }
    
    private func languageBadge(_ language: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(languageColor(language))
                .frame(width: 8, height: 8)
            Text(language)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.joltForeground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.joltMuted)
        .cornerRadius(8)
    }
    
    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return Color(hex: "#F05138")
        case "javascript", "typescript": return Color(hex: "#F7DF1E")
        case "python": return Color(hex: "#3776AB")
        case "rust": return Color(hex: "#DEA584")
        case "go": return Color(hex: "#00ADD8")
        case "java": return Color(hex: "#B07219")
        case "kotlin": return Color(hex: "#A97BFF")
        case "ruby": return Color(hex: "#CC342D")
        default: return Color(hex: "#8E8E93")
        }
    }
    
    private func formatDuration(_ iso: String) -> String {
        // Parse PT1H23M45S format
        var hours = 0
        var minutes = 0
        var seconds = 0
        
        var numStr = ""
        for char in iso {
            if char.isNumber {
                numStr += String(char)
            } else if char == "H" {
                hours = Int(numStr) ?? 0
                numStr = ""
            } else if char == "M" {
                minutes = Int(numStr) ?? 0
                numStr = ""
            } else if char == "S" {
                seconds = Int(numStr) ?? 0
                numStr = ""
            }
        }
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else if minutes > 0 || seconds > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
        return ""
    }
}

// MARK: - Reader Settings Sheet

struct ReaderSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var themeRaw: String
    @Binding var lineHeight: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Font Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("reader.textSize".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 14))
                            .foregroundColor(.joltMutedForeground)
                        
                        Slider(value: $fontSize, in: 14...26, step: 1)
                            .tint(.joltYellow)
                        
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 18))
                            .foregroundColor(.joltMutedForeground)
                    }
                    
                    Text("\(Int(fontSize))pt")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.joltYellow)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Theme
                VStack(alignment: .leading, spacing: 12) {
                    Text("reader.theme".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                    
                    HStack(spacing: 12) {
                        ForEach(ReaderSettings.Theme.allCases, id: \.rawValue) { theme in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    themeRaw = theme.rawValue
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(theme.backgroundColor)
                                        .frame(height: 44)
                                        .overlay(
                                            Text("Aa")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(theme.textColor)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeRaw == theme.rawValue ? Color.joltYellow : Color.joltBorder, lineWidth: 2)
                                        )
                                    
                                    Text(theme.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(themeRaw == theme.rawValue ? .joltYellow : .joltMutedForeground)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Line Height
                VStack(alignment: .leading, spacing: 12) {
                    Text("reader.lineSpacing".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.joltMutedForeground)
                    
                    HStack(spacing: 12) {
                        ForEach([("reader.lineSpacing.compact".localized, 1.4), ("reader.lineSpacing.normal".localized, 1.6), ("reader.lineSpacing.relaxed".localized, 1.8)], id: \.0) { name, value in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    lineHeight = value
                                }
                            } label: {
                                Text(name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(lineHeight == value ? .joltBackground : .joltForeground)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(lineHeight == value ? Color.joltYellow : Color.joltMuted)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color.joltBackground)
            .navigationTitle("reader.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(.joltYellow)
                }
            }
        }
    }
}

// MARK: - Enhanced Article Reader View (WKWebView-based)

struct EnhancedArticleReaderView: View {
    let bookmark: Bookmark
    let fontSize: Double
    let theme: ReaderSettings.Theme
    let lineHeight: Double
    @Binding var scrollProgress: Double
    let onJolt: () -> Void
    let isArchived: Bool
    
    @State private var webView: WKWebView?
    @State private var isLoading = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ArticleWebView(
                bookmark: bookmark,
                fontSize: fontSize,
                theme: theme,
                lineHeight: lineHeight,
                scrollProgress: $scrollProgress,
                webView: $webView,
                isLoading: $isLoading
            )
            .padding(.bottom, 76)
            
            ReaderToolbar(
                canGoBack: false,
                canGoForward: false,
                scrollProgress: scrollProgress,
                isArchived: isArchived,
                onBack: {},
                onForward: {},
                onJolt: onJolt
            )
        }
    }
}

struct ArticleWebView: UIViewRepresentable {
    let bookmark: Bookmark
    let fontSize: Double
    let theme: ReaderSettings.Theme
    let lineHeight: Double
    @Binding var scrollProgress: Double
    @Binding var webView: WKWebView?
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        
        // Style
        webView.isOpaque = false
        webView.backgroundColor = UIColor(theme.backgroundColor)
        webView.scrollView.backgroundColor = UIColor(theme.backgroundColor)
        
        // Load content
        loadContent(in: webView)
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update styles when settings change
        injectStyles(in: webView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadContent(in webView: WKWebView) {
        let html = bookmark.contentHTML ?? "<p>No content available</p>"
        let fullHTML = buildHTMLDocument(content: html)
        webView.loadHTMLString(fullHTML, baseURL: URL(string: bookmark.originalURL))
    }
    
    private func injectStyles(in webView: WKWebView) {
        let bgColor: String
        let textColor: String
        
        switch theme {
        case .dark:
            bgColor = "#141414"
            textColor = "rgba(255,255,255,0.9)"
        case .sepia:
            bgColor = "#F4ECD8"
            textColor = "#5B4636"
        case .light:
            bgColor = "#FFFFFF"
            textColor = "#1C1C1E"
        }
        
        let script = """
            document.body.style.fontSize = '\(Int(fontSize))px';
            document.body.style.lineHeight = '\(lineHeight)';
            document.body.style.backgroundColor = '\(bgColor)';
            document.body.style.color = '\(textColor)';
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    private func buildHTMLDocument(content: String) -> String {
        let bgColor: String
        let textColor: String
        let linkColor = theme.linkColor
        
        switch theme {
        case .dark:
            bgColor = "#141414"
            textColor = "rgba(255,255,255,0.9)"
        case .sepia:
            bgColor = "#F4ECD8"
            textColor = "#5B4636"
        case .light:
            bgColor = "#FFFFFF"
            textColor = "#1C1C1E"
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: \(Int(fontSize))px;
                    line-height: \(lineHeight);
                    color: \(textColor);
                    background-color: \(bgColor);
                    padding: 0 20px 100px 20px;
                    margin: 0;
                    word-wrap: break-word;
                    -webkit-font-smoothing: antialiased;
                }
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 700;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    line-height: 1.3;
                }
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                p {
                    margin: 1em 0;
                }
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 1em 0;
                    display: block;
                }
                pre, code {
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 0.9em;
                    background-color: \(theme == .dark ? "#1e1e1e" : (theme == .sepia ? "#E8E0CC" : "#F5F5F5"));
                    border-radius: 6px;
                    overflow-x: auto;
                }
                pre {
                    padding: 16px;
                    margin: 1em 0;
                }
                code {
                    padding: 2px 6px;
                }
                pre code {
                    padding: 0;
                    background: none;
                }
                blockquote {
                    border-left: 3px solid \(linkColor);
                    margin: 1em 0;
                    padding-left: 16px;
                    font-style: italic;
                    opacity: 0.9;
                }
                ul, ol {
                    padding-left: 24px;
                    margin: 1em 0;
                }
                li {
                    margin: 0.5em 0;
                }
                hr {
                    border: none;
                    border-top: 1px solid \(theme == .dark ? "#333" : "#ddd");
                    margin: 2em 0;
                }
                figure {
                    margin: 1em 0;
                }
                figcaption {
                    font-size: 0.85em;
                    opacity: 0.7;
                    text-align: center;
                    margin-top: 0.5em;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1em 0;
                    font-size: 0.9em;
                }
                th, td {
                    padding: 8px 12px;
                    border: 1px solid \(theme == .dark ? "#333" : "#ddd");
                    text-align: left;
                }
                th {
                    background-color: \(theme == .dark ? "#1e1e1e" : (theme == .sepia ? "#E8E0CC" : "#F5F5F5"));
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: ArticleWebView
        
        init(_ parent: ArticleWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Restore scroll position
            if let lastScroll = parent.bookmark.lastScrollPercentage, lastScroll > 0.05 {
                let script = """
                    setTimeout(function() {
                        window.scrollTo(0, document.body.scrollHeight * \(lastScroll));
                    }, 100);
                """
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            let offsetY = scrollView.contentOffset.y
            
            if contentHeight > frameHeight {
                let percentage = offsetY / (contentHeight - frameHeight)
                let clampedPercentage = min(max(percentage, 0), 1)
                
                DispatchQueue.main.async {
                    self.parent.scrollProgress = clampedPercentage
                }
                
                // Save scroll position
                parent.bookmark.lastScrollPercentage = clampedPercentage
            }
        }
        
        // Handle link clicks - open in Safari
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - PDF Reader View

struct PDFReaderView: View {
    let url: URL?
    let bookmark: Bookmark
    @Binding var scrollProgress: Double
    let onJolt: () -> Void
    let isArchived: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = url {
                PDFKitView(url: url, scrollProgress: $scrollProgress)
                    .padding(.bottom, 76)
            } else {
                VStack {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.joltMutedForeground)
                    Text("reader.unableToLoadPDF".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.joltMutedForeground)
                }
            }
            
            ReaderToolbar(
                canGoBack: false,
                canGoForward: false,
                scrollProgress: scrollProgress,
                isArchived: isArchived,
                onBack: {},
                onForward: {},
                onJolt: onJolt
            )
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var scrollProgress: Double
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        // Observe page changes for progress
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            
            let pageCount = document.pageCount
            let currentIndex = document.index(for: currentPage)
            
            DispatchQueue.main.async {
                self.parent.scrollProgress = Double(currentIndex + 1) / Double(pageCount)
            }
        }
    }
}

// MARK: - Web Reader View

struct WebReaderView: View {
    let url: String
    let bookmark: Bookmark
    @Binding var scrollProgress: Double
    let onJolt: () -> Void
    let isArchived: Bool
    
    @State private var isLoading = true
    @State private var loadingProgress: Double = 0
    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var showOffline = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if showOffline, let _ = bookmark.contentHTML {
                // Fallback to article view
                ArticleWebView(
                    bookmark: bookmark,
                    fontSize: 18,
                    theme: .dark,
                    lineHeight: 1.6,
                    scrollProgress: $scrollProgress,
                    webView: .constant(nil),
                    isLoading: .constant(false)
                )
                .padding(.bottom, 76)
            } else {
                ZStack(alignment: .top) {
                    WebViewRepresentable(
                        url: url,
                        bookmark: bookmark,
                        isLoading: $isLoading,
                        progress: $loadingProgress,
                        webView: $webView,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        scrollProgress: $scrollProgress,
                        showOffline: $showOffline
                    )
                    .padding(.bottom, 76)
                    
                    if isLoading {
                        ProgressView(value: loadingProgress)
                            .tint(.joltYellow)
                    }
                }
            }
            
            ReaderToolbar(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                scrollProgress: scrollProgress,
                isArchived: isArchived,
                onBack: { webView?.goBack() },
                onForward: { webView?.goForward() },
                onJolt: onJolt
            )
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: String
    let bookmark: Bookmark
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var scrollProgress: Double
    @Binding var showOffline: Bool
    
    private func isXComURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("x.com") || lowercased.contains("twitter.com")
    }
    
    private func isYouTubeURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("youtube.com") || lowercased.contains("youtu.be")
    }
    
    private func urlWithResumePosition(_ urlString: String) -> String {
        // If we have a saved video position and this is a YouTube URL, append it
        guard isYouTubeURL(urlString),
              let position = bookmark.lastVideoPosition,
              position > 10 else { // Only resume if > 10 seconds
            return urlString
        }
        
        // Check if URL already has time parameter
        if urlString.contains("&t=") || urlString.contains("?t=") {
            return urlString
        }
        
        // Append time parameter
        let separator = urlString.contains("?") ? "&" : "?"
        return "\(urlString)\(separator)t=\(position)"
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add message handler for video progress
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "videoProgress")
        
        if isXComURL(url) {
            configuration.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"
            configuration.dataDetectorTypes = []
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        if isXComURL(url) {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        }
        
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        
        // Use URL with resume position for YouTube
        let finalURL = urlWithResumePosition(url)
        if let loadURL = URL(string: finalURL) {
            var request = URLRequest(url: loadURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            webView.load(request)
            
            if finalURL != url {
                print("▶️ Resuming YouTube video at \(bookmark.lastVideoPosition ?? 0)s")
            }
        }
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var parent: WebViewRepresentable
        private var progressObservation: NSKeyValueObservation?
        private var backObservation: NSKeyValueObservation?
        private var forwardObservation: NSKeyValueObservation?
        private var redirectCount = 0
        private let maxRedirects = 5
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - WKScriptMessageHandler (Video Position Tracking)
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoProgress",
               let position = message.body as? Int {
                // Only save if position changed significantly (> 5 seconds difference)
                let currentPosition = parent.bookmark.lastVideoPosition ?? 0
                if abs(position - currentPosition) > 5 {
                    parent.bookmark.lastVideoPosition = position
                    print("🎬 Video position saved: \(position)s")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            redirectCount += 1
            if redirectCount > maxRedirects {
                webView.stopLoading()
                print("⚠️ Redirect loop detected, stopping load.")
            }
            
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = webView.estimatedProgress
                }
            }
            
            backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = webView.canGoBack
                }
            }
            
            forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = webView.canGoForward
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            redirectCount = 0
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.progress = 1.0
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
            self.progressObservation?.invalidate()
            
            // Restore scroll position
            if let lastScroll = parent.bookmark.lastScrollPercentage {
                let script = """
                    setTimeout(function() {
                        window.scrollTo(0, document.body.scrollHeight * \(lastScroll));
                    }, 500);
                """
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
            
            webView.scrollView.delegate = self
            
            // Dark mode CSS injection
            let css = """
                body {
                    background-color: #141414 !important;
                    color: #e8e8e8 !important;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif !important;
                    line-height: 1.6 !important;
                    padding: 20px !important;
                }
                a { color: #CCFF00 !important; }
                img { max-width: 100% !important; height: auto !important; border-radius: 8px !important; }
                pre, code { background-color: #1e1e1e !important; color: #d4d4d4 !important; padding: 12px !important; border-radius: 6px !important; }
            """
            
            let cssScript = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
            webView.evaluateJavaScript(cssScript, completionHandler: nil)
            
            // YouTube video position tracking script
            if parent.isYouTubeURL(parent.url) {
                let videoTrackingScript = """
                    setInterval(function() {
                        var video = document.querySelector('video');
                        if (video && video.currentTime > 0) {
                            window.webkit.messageHandlers.videoProgress.postMessage(Math.floor(video.currentTime));
                        }
                    }, 5000);
                """
                webView.evaluateJavaScript(videoTrackingScript, completionHandler: nil)
                print("🎬 YouTube video tracking script injected")
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            let offsetY = scrollView.contentOffset.y
            
            if contentHeight > frameHeight {
                let percentage = offsetY / (contentHeight - frameHeight)
                let clampedPercentage = min(max(percentage, 0), 1)
                
                DispatchQueue.main.async {
                    self.parent.scrollProgress = clampedPercentage
                }
                
                parent.bookmark.lastScrollPercentage = percentage
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                if self.parent.bookmark.contentHTML != nil {
                    self.parent.showOffline = true
                }
            }
            self.progressObservation?.invalidate()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                if self.parent.bookmark.contentHTML != nil {
                    self.parent.showOffline = true
                }
            }
            self.progressObservation?.invalidate()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 || httpResponse.statusCode >= 500 {
                    DispatchQueue.main.async {
                        if self.parent.bookmark.contentHTML != nil {
                            self.parent.showOffline = true
                        }
                    }
                }
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            if url.host?.contains("itunes.apple.com") == true || url.host?.contains("apps.apple.com") == true {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            
            if let scheme = url.scheme?.lowercased() {
                if scheme == "http" || scheme == "https" {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - Reader Toolbar

struct ReaderToolbar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let scrollProgress: Double
    let isArchived: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onJolt: () -> Void
    
    var body: some View {
        HStack {
            // Back Button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(canGoBack ? .white : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("a11y.reader.back".localized)
            .accessibilityHint(canGoBack ? "a11y.reader.backHint".localized : "a11y.reader.backDisabled".localized)
            
            Spacer()
            
            // Jolt It Button
            if !isArchived {
                JoltButton(scrollProgress: scrollProgress, action: onJolt)
            } else {
                // Archived State Indicator
                ZStack {
                    Circle()
                        .stroke(Color.joltYellow, lineWidth: 3)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.joltYellow)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("a11y.reader.alreadyRead".localized)
            }
            
            Spacer()
            
            // Forward Button
            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(canGoForward ? .white : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("a11y.reader.forward".localized)
            .accessibilityHint(canGoForward ? "a11y.reader.forwardHint".localized : "a11y.reader.forwardDisabled".localized)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background(Color.joltBackground.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .top
        )
    }
}

// MARK: - Jolt Button (Sacred - Keep all animations!)

struct JoltButton: View {
    let scrollProgress: Double
    let action: () -> Void
    
    @State private var isAnimating = false
    @State private var showParticles = false
    @State private var showRipple = false
    @State private var showCheckmark = false
    @State private var iconRotation: Double = 0
    @State private var buttonScale: CGFloat = 1.0
    @State private var isPressed = false
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    private var progressPercent: Int {
        Int(scrollProgress * 100)
    }
    
    var body: some View {
        ZStack {
            // Ripple Effect
            if showRipple && !reduceMotion {
                Circle()
                    .stroke(Color.joltYellow.opacity(0.5), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(2.5)
                    .opacity(0)
                    .animation(.easeOut(duration: 0.6), value: showRipple)
                
                Circle()
                    .stroke(Color.joltYellow.opacity(0.3), lineWidth: 1)
                    .frame(width: 56, height: 56)
                    .scaleEffect(2.0)
                    .opacity(0)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: showRipple)
            }
            
            // Particles
            if showParticles && !reduceMotion {
                JoltParticles()
            }
            
            // Main Button
            ZStack {
                // Progress Ring Background
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                // Progress Ring Active
                Circle()
                    .trim(from: 0, to: scrollProgress)
                    .stroke(Color.joltYellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: scrollProgress)
                
                // Button Icon Background
                Circle()
                    .fill(Color.joltBackground)
                    .frame(width: 48, height: 48)
                
                // Icons
                ZStack {
                    if showCheckmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.joltYellow)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isPressed ? .joltYellow : .joltYellow.opacity(0.8))
                            .shadow(color: isPressed ? .joltYellow.opacity(0.8) : .clear, radius: 8)
                            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 1.1 : 1.0))
                            .rotationEffect(.degrees(reduceMotion ? 0 : iconRotation))
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isPressed)
                    }
                }
            }
            .scaleEffect(buttonScale)
            .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
                if !isAnimating {
                    isPressed = pressing
                }
            }, perform: {
                startJoltSequence()
            })
        }
        // MARK: Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(A11y.Reader.joltButton)
        .accessibilityHint(A11y.Reader.joltHint)
        .accessibilityValue("a11y.reader.progressValue".localized(with: progressPercent))
        .accessibilityAddTraits(.isButton)
    }
    
    private func startJoltSequence() {
        guard !isAnimating else { return }
        isAnimating = true
        isPressed = false
        
        // T=0.0s: Trigger & Haptic
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Announce for VoiceOver
        AccessibilityNotification.Announcement("İçerik tamamlandı olarak işaretleniyor").post()
        
        if reduceMotion {
            // Skip all animations for reduce motion
            showCheckmark = true
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                action()
            }
            return
        }
        
        // Button press effect
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 0.9
        }
        
        // T=0.1s: Explosion (Particles & Ripple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1.0
            }
            showParticles = true
            showRipple = true
        }
        
        // T=0.3s: Transformation (Bolt -> Checkmark)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                iconRotation = 360
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                showCheckmark = true
            }
            
            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
        }
        
        // T=1.3s: Completion & Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            action()
        }
    }
}

// MARK: - Jolt Particles

struct JoltParticles: View {
    @State private var time: Double = 0.0
    
    struct Particle: Hashable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let scale: CGFloat
        let speed: Double
    }
    
    let particles: [Particle] = (0..<20).map { _ in
        Particle(
            angle: Double.random(in: 0..<360),
            distance: CGFloat.random(in: 60...100),
            scale: CGFloat.random(in: 0.5...1.2),
            speed: Double.random(in: 0.5...1.0)
        )
    }
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.self) { particle in
                Circle()
                    .fill(Color.joltYellow)
                    .frame(width: 6, height: 6)
                    .scaleEffect(particle.scale * (1 - time))
                    .offset(
                        x: time * particle.distance * cos(particle.angle * .pi / 180),
                        y: time * particle.distance * sin(particle.angle * .pi / 180)
                    )
                    .opacity(1 - time)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                time = 1.0
            }
        }
    }
}

// MARK: - Content Status Banner

/// Displays an info banner for protected or paywalled content
struct ContentStatusBanner: View {
    let bookmark: Bookmark
    @State private var isExpanded = false
    
    private var bannerInfo: (icon: String, title: String, subtitle: String, color: Color) {
        if bookmark.isProtected == true {
            return (
                "lock.shield.fill",
                String(localized: "reader.protected.title", defaultValue: "Login Required"),
                String(localized: "reader.protected.subtitle", defaultValue: "This content requires authentication. Sign in on the website to view."),
                .orange
            )
        } else if bookmark.isPaywalled == true {
            return (
                "creditcard.fill",
                String(localized: "reader.paywall.title", defaultValue: "Premium Content"),
                String(localized: "reader.paywall.subtitle", defaultValue: "This article may be behind a paywall. Limited preview available."),
                .purple
            )
        } else {
            return (
                "globe",
                String(localized: "reader.webview.title", defaultValue: "Web View"),
                String(localized: "reader.webview.subtitle", defaultValue: "Opening in web view for best experience."),
                .blue
            )
        }
    }
    
    var body: some View {
        let info = bannerInfo
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: info.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(info.color)
                
                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.joltForeground)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.joltMutedForeground)
                }
            }
            
            if isExpanded {
                Text(info.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.joltMutedForeground)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(info.color.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(info.color)
                .frame(width: 3),
            alignment: .leading
        )
    }
}

/// Displays a banner when content couldn't be parsed and we fell back to WebView
struct ContentFallbackBanner: View {
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("reader.fallback.title".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.joltForeground)
                    
                    Text("reader.fallback.subtitle".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.joltMutedForeground)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.joltMutedForeground)
                        .padding(6)
                        .background(Color.joltMuted)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .overlay(
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 3),
                alignment: .leading
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isDismissed = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReaderView(
            bookmark: Bookmark(
                userID: "test",
                originalURL: "https://github.com/apple/swift",
                scheduledFor: Date(),
                contentHTML: "<h1>Hello World</h1><p>This is a <strong>test article</strong> with some content.</p><pre><code>let x = 42</code></pre>",
                title: "Swift Programming Language",
                excerpt: "Swift is a powerful and intuitive programming language",
                coverImage: "https://repository-images.githubusercontent.com/44838949/7b6b0680-8a68-11ea-8b71-ef5e8a5af22c",
                readingTimeMinutes: 5,
                type: .code,
                domain: "github.com",
                userNote: "Check this for async/await patterns",
                metadata: ["stars": "67.5k", "forks": "10.8k", "language": "Swift"]
            )
        )
    }
    .modelContainer(for: Bookmark.self, inMemory: true)
}
