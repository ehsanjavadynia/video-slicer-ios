import Foundation

protocol VideoSlicerServiceProtocol {
    func slice(
        asset: VideoAsset,
        settings: SliceSettings
    ) async throws -> AsyncThrowingStream<SlicingProgress, Error>

    func cancel(assetID: UUID)
}

struct SlicingProgress {
    let assetID: UUID
    let completedSegments: Int
    let totalSegments: Int
    let latestOutput: OutputVideo?
    let isComplete: Bool

    var fraction: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(completedSegments) / Double(totalSegments)
    }
}

enum SlicingError: LocalizedError {
    case zeroDuration
    case invalidSettings
    case assetLoadFailed
    case outputDirectoryFailed

    var errorDescription: String? {
        switch self {
        case .zeroDuration: return "The video has zero duration."
        case .invalidSettings: return "Invalid slicing settings provided."
        case .assetLoadFailed: return "Failed to load the video asset."
        case .outputDirectoryFailed: return "Failed to create output directory."
        }
    }
}
