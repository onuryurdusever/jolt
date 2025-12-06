import UIKit
import Combine

class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
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
        
        // 2. Check Disk (Synchronous read on calling thread - usually main for UI, but fast enough for small images)
        // Ideally we should load async, but for a simple cache check, this might be okay if images are small.
        // However, for scrolling performance, we should probably rely on the loader to call this async.
        // Let's keep this simple: The Loader will call this.
        
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
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let filename = self.cacheKey(for: url)
            let fileURL = self.diskCacheDirectory.appendingPathComponent(filename)
            
            // Compress and write
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheDirectory)
            try? self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func cacheKey(for url: URL) -> String {
        // Simple hash or encoding
        return String(url.absoluteString.hashValue)
    }
}
