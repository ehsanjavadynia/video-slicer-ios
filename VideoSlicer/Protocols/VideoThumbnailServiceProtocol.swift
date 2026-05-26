import AVFoundation
import CoreGraphics
import UIKit

protocol VideoThumbnailServiceProtocol {
    func thumbnail(for url: URL, at time: CMTime, size: CGSize) async throws -> UIImage
    func clearCache()
}

enum ThumbnailError: LocalizedError {
    case generationFailed(String)
    case invalidAsset

    var errorDescription: String? {
        switch self {
        case .generationFailed(let reason): return "Thumbnail generation failed: \(reason)"
        case .invalidAsset: return "Invalid video asset for thumbnail."
        }
    }
}
