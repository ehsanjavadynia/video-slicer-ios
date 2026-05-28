import UIKit
@testable import VideoSlicer

final class MockGalleryService: GalleryServiceProtocol {

    var stubbedAsset: VideoAsset?
    var shouldThrow = false
    var thrownError: GalleryError = .cancelled
    var pickCallCount = 0

    func pickVideo(
        presentingViewController: UIViewController,
        onProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> VideoAsset {
        pickCallCount += 1
        if shouldThrow {
            throw thrownError
        }
        guard let asset = stubbedAsset else {
            throw GalleryError.cancelled
        }
        return asset
    }
}
