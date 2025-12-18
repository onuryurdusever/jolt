//
//  ActionViewController.swift
//  jolt
//
//  Created by Onur Yurdusever on 10.12.2025.
//


//
//  ActionViewController.swift
//  JoltActionExtension
//
//  Jolt'a Ekle - UI olmadan hızlı bookmark ekleme
//

import UIKit
import SwiftData
import UniformTypeIdentifiers
import MobileCoreServices

@objc(ActionViewController)
class ActionViewController: UIViewController {
    private var modelContainer: ModelContainer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Görünmez view
        view.backgroundColor = .clear
        view.isHidden = true
        
        // SwiftData Container kurulumu
        setupModelContainer()
        
        // URL'i al ve kaydet
        extractAndSaveURL()
    }
    
    private func setupModelContainer() {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jolt.shared") else {
            print("❌ Failed to get App Group container")
            return
        }
        
        let schema = Schema([Bookmark.self, Routine.self])
        let modelConfiguration = ModelConfiguration(
            url: appGroupURL.appendingPathComponent("jolt.sqlite"),
            allowsSave: true
        )
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ActionExtension ModelContainer created")
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
        }
    }
    
    private func extractAndSaveURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            done()
            return
        }
        
        for attachment in attachments {
            // URL tipini kontrol et
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    let extractedURL = item as? URL
                    let extractedString = item as? String
                    
                    DispatchQueue.main.async {
                        if let shareURL = extractedURL {
                            self?.saveBookmark(urlString: shareURL.absoluteString)
                        } else if let urlString = extractedString {
                            self?.saveBookmark(urlString: urlString)
                        } else {
                            self?.done()
                        }
                    }
                }
                return
            }
            
            // Plain text olarak URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    let extractedString = item as? String
                    
                    DispatchQueue.main.async {
                        if let urlString = extractedString,
                           let url = URL(string: urlString),
                           url.scheme == "http" || url.scheme == "https" {
                            self?.saveBookmark(urlString: urlString)
                        } else {
                            self?.done()
                        }
                    }
                }
                return
            }
        }
        
        done()
    }
    
    private func saveBookmark(urlString: String) {
        guard let container = modelContainer else {
            print("❌ No ModelContainer")
            done()
            return
        }
        
        let userID = loadUserID() ?? "anonymous"
        
        // Domain'i çıkar
        let domain = URL(string: urlString)?.host ?? "unknown"
        
        // Yeni bookmark oluştur - v2.1 DOZ fields
        let bookmark = Bookmark(
            userID: userID,
            originalURL: urlString,
            status: .active,
            scheduledFor: Date(),
            title: domain, // Başlık daha sonra sync ile güncellenecek
            type: .article,
            domain: domain,
            expiresAt: Date().addingTimeInterval(24 * 60 * 60), // 24 saat
            intent: .now, // Varsayılan olarak "Şimdi" intent'i
            // v3.1 Enrichment: Force enrichment for new items
            needsEnrichment: true,
            enrichmentStatus: .pending
        )
        
        let context = container.mainContext
        context.insert(bookmark)
        
        do {
            try context.save()
            print("✅ Bookmark saved via Action Extension: \(urlString)")
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("❌ Failed to save bookmark: \(error)")
        }
        
        done()
    }
    
    private func loadUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "jolt.userId",
            kSecAttrAccessGroup as String: "group.com.jolt.shared",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func done() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
