import UIKit

protocol GalleryServiceProtocol {
    /// Picks a video from the photo library.
    /// - Parameter onProgress: invoked on the main actor with values in 0...1
    ///   while the picked video is being fetched (e.g. iCloud download). May
    ///   not fire for assets that are already local.
    func pickVideo(
        presentingViewController: UIViewController,
        onProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> VideoAsset
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
