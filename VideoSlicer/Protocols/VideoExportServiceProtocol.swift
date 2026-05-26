import AVFoundation
import Foundation

protocol VideoExportServiceProtocol {
    func export(
        avAsset: AVAsset,
        timeRange: CMTimeRange,
        outputURL: URL,
        resolution: VideoResolution,
        quality: VideoQuality
    ) async throws -> URL

    var outputFileExtension: String { get }
}

enum ExportError: LocalizedError {
    case sourceNotFound
    case exportSessionCreationFailed
    case exportFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sourceNotFound: return "Source video file not found."
        case .exportSessionCreationFailed: return "Failed to create export session."
        case .exportFailed(let reason): return "Export failed: \(reason)"
        case .cancelled: return "Export was cancelled."
        }
    }
}
