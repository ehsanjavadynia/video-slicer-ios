import AVFoundation
import UIKit
@testable import VideoSlicer

final class MockVideoThumbnailService: VideoThumbnailServiceProtocol {

    var stubbedImage: UIImage? = UIImage()
    var thumbnailCallCount = 0
    var clearCacheCallCount = 0
    var shouldThrow = false

    func thumbnail(for url: URL, at time: CMTime, size: CGSize) async throws -> UIImage {
        thumbnailCallCount += 1
        if shouldThrow {
            throw ThumbnailError.invalidAsset
        }
        return stubbedImage ?? UIImage()
    }

    func clearCache() {
        clearCacheCallCount += 1
    }
}
