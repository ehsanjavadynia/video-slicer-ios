import AVFoundation
import Kingfisher
import UIKit

final class VideoThumbnailService: VideoThumbnailServiceProtocol {

    private let cache: ImageCache

    init() {
        self.cache = ImageCache(name: "VideoThumbnails")
        self.cache.diskStorage.config.sizeLimit = 100 * 1024 * 1024 // 100 MB
    }

    func thumbnail(for url: URL, at time: CMTime, size: CGSize) async throws -> UIImage {
        let cacheKey = "\(url.path)_\(time.value)_\(time.timescale)"

        if let cached = await cachedImage(forKey: cacheKey) {
            return cached
        }

        let image = try await generateThumbnail(url: url, time: time, size: size)
        cache.store(image, forKey: cacheKey)
        return image
    }

    func clearCache() {
        cache.clearMemoryCache()
        cache.clearDiskCache()
    }

    private func cachedImage(forKey key: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            cache.retrieveImage(forKey: key) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func generateThumbnail(url: URL, time: CMTime, size: CGSize) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        return try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error {
                    continuation.resume(throwing: ThumbnailError.generationFailed(error.localizedDescription))
                    return
                }
                guard let cgImage else {
                    continuation.resume(throwing: ThumbnailError.invalidAsset)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
}
