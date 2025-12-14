import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allBookmarks: [Bookmark]
    
    @State private var showClearImageCacheAlert = false
    @State private var showClearArticleCacheAlert = false
    @State private var cacheSize: String = "Calculating..."
    
    // Export State
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.joltBackground
                    .ignoresSafeArea()
                
                List {
                    // MARK: - Storage & Cache Section
                    Section {
                        HStack {
                            Text("settings.imageCache".localized)
                            Spacer()
                            Button("common.clear".localized) {
                                showClearImageCacheAlert = true
                            }
                            .foregroundColor(.red)
                        }
                        
                        HStack {
                            Text("settings.articleCache".localized)
                            Spacer()
                            Button("common.clear".localized) {
                                showClearArticleCacheAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    } header: {
                        Text("settings.storageCache".localized)
                            .foregroundColor(.gray)
                    } footer: {
                        Text("settings.clearCache.description".localized)
                            .foregroundColor(.gray)
                    }
                    
                    Section {
                        Button {
                            exportData()
                        } label: {
                            if isExporting {
                                HStack {
                                    Text("common.exporting".localized)
                                    Spacer()
                                    ProgressView()
                                }
                            } else {
                                HStack {
                                    Text("settings.exportData".localized)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        .foregroundColor(.joltForeground)
                    } header: {
                        Text("settings.dataManagement".localized)
                            .foregroundColor(.gray)
                    } footer: {
                        Text("settings.export.description".localized)
                            .foregroundColor(.gray)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("settings.storageDataCache".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#CCFF00"))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("alert.clearImageCache.title".localized, isPresented: $showClearImageCacheAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.clear".localized, role: .destructive) {
                    clearImageCache()
                }
            } message: {
                Text("alert.clearImageCache.message".localized)
            }
            .alert("alert.clearArticleCache.title".localized, isPresented: $showClearArticleCacheAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.clear".localized, role: .destructive) {
                    clearArticleCache()
                }
            } message: {
                Text("alert.clearArticleCache.message".localized)
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            // Create DTOs
            let bookmarkDTOs = allBookmarks.map { bookmark in
                BookmarkDTO(
                    id: bookmark.id,
                    originalURL: bookmark.originalURL,
                    status: bookmark.status.rawValue,
                    title: bookmark.title,
                    userNote: bookmark.userNote,
                    createdAt: bookmark.createdAt,
                    type: bookmark.type.rawValue
                )
            }
            

            
            let exportData = ExportData(
                version: "1.0",
                exportedAt: Date(),
                bookmarks: bookmarkDTOs
            )
            
            // Encode to JSON
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(exportData)
                
                // Save to temp file
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "jolt_export_\(Date().ISO8601Format().replacingOccurrences(of: ":", with: "-")).json"
                let fileURL = tempDir.appendingPathComponent(fileName)
                
                try data.write(to: fileURL)
                
                await MainActor.run {
                    self.exportURL = fileURL
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                print("❌ Export failed: \(error)")
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
    
    private func clearImageCache() {
        ImageCacheService.shared.clearCache()
        // Optional: Trigger a UI refresh or toast
    }
    
    private func clearArticleCache() {
        // Iterate over all bookmarks and clear contentHTML
        // We should probably only clear archived ones? Or all?
        // The requirement says "Önbelleği Temizle (Resimler ve HTML verisi)".
        // Usually this means freeing up space, so clearing all HTML content is valid.
        // The user can re-fetch if needed (though currently we don't have a re-fetch mechanism in UI, 
        // but ReaderView falls back to WebView).
        
        var count = 0
        for bookmark in allBookmarks {
            if bookmark.contentHTML != nil {
                bookmark.contentHTML = nil
                count += 1
            }
        }
        
        do {
            try modelContext.save()
            print("✅ Cleared HTML content for \(count) bookmarks")
        } catch {
            print("❌ Failed to save after clearing cache: \(error)")
        }
    }
}

// MARK: - Export DTOs

struct ExportData: Codable {
    let version: String
    let exportedAt: Date
    let bookmarks: [BookmarkDTO]
}



struct BookmarkDTO: Codable {
    let id: UUID
    let originalURL: String
    let status: String
    let title: String
    let userNote: String?
    let createdAt: Date
    let type: String
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
