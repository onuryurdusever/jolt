import UIKit
import Combine

@MainActor
class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    // SAFETY: Mark as nonisolated to allow access from background queues without MainActor warnings/crashes
    nonisolated private let diskCacheDirectory: URL
    
    private let ioQueue = DispatchQueue(label: "com.jolt.imagecache.io", qos: .background)
    
    init() {
        // Setup disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheDirectory = paths[0].appendingPathComponent("JoltImageCache")
        
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. Check Memory
        if let image = memoryCache.object(forKey: key) {
            return image
        }
        
        // 2. Check Disk
        let filename = cacheKey(for: url)
        let fileURL = diskCacheDirectory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            
            // Restore to memory
            memoryCache.setObject(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    func save(_ image: UIImage, for url: URL) {
        let key = url.absoluteString as NSString
        
        // 1. Save to Memory
        memoryCache.setObject(image, forKey: key)
        
        // 2. Save to Disk (Async)
        // Capture necessary values to avoid "self" usage for properties that might trigger isolation checks
        let filename = cacheKey(for: url)
        let fileURL = diskCacheDirectory.appendingPathComponent(filename)
        // Copy data on main thread/caller to avoid accessing UIImage (MainActor-ish) on background
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        ioQueue.async {
            guard let data = imageData else { return }
            try? data.write(to: fileURL)
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        let directory = diskCacheDirectory
        ioQueue.async {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    nonisolated private func cacheKey(for url: URL) -> String {
        // Simple hash or encoding
        return String(url.absoluteString.hashValue)
    }
}
