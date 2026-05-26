import UIKit

protocol GalleryServiceProtocol {
    func pickVideo(presentingViewController: UIViewController) async throws -> VideoAsset
}

enum GalleryError: LocalizedError {
    case cancelled
    case exportFailed(String)
    case unsupportedFormat
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Video selection was cancelled."
        case .exportFailed(let reason): return "Failed to export video: \(reason)"
        case .unsupportedFormat: return "The selected file format is not supported."
        case .permissionDenied: return "Photo library access was denied."
        }
    }
}
