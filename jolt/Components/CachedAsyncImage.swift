import SwiftUI
import Combine

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @StateObject private var loader: ImageLoader
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self._loader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
        .onChange(of: url) { _, newURL in
            loader.url = newURL
            loader.load()
        }
    }
}

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    var url: URL?
    private var cancellable: AnyCancellable?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else {
            self.image = nil
            return
        }
        
        // Check cache first
        if let cached = ImageCacheService.shared.image(for: url) {
            self.image = cached
            return
        }
        
        // Download
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .receive(on: DispatchQueue.main) // Move to Main Immediately to satisfy Actor isolation
            .map { $0.data } 
            .replaceError(with: nil)
            .sink { [weak self] data in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                
                // Now we are on MainActor, and UIImage is created on Main Thread
                self.image = image
                ImageCacheService.shared.save(image, for: url)
            }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}
