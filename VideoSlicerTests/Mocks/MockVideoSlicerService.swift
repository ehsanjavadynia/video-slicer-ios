import Foundation
@testable import VideoSlicer

final class MockVideoSlicerService: VideoSlicerServiceProtocol {

    var sliceCallCount = 0
    var lastSlicedAsset: VideoAsset?
    var lastSettings: SliceSettings?
    var stubbedOutputVideos: [OutputVideo] = []
    var shouldThrow = false
    var cancelCallCount = 0

    func slice(asset: VideoAsset, settings: SliceSettings) async throws -> AsyncThrowingStream<SlicingProgress, Error> {
        sliceCallCount += 1
        lastSlicedAsset = asset
        lastSettings = settings

        if shouldThrow {
            throw SlicingError.assetLoadFailed
        }

        let outputs = stubbedOutputVideos
        let assetID = asset.id
        return AsyncThrowingStream { continuation in
            let total = max(outputs.count, 1)
            for (index, output) in outputs.enumerated() {
                let progress = SlicingProgress(
                    assetID: assetID,
                    completedSegments: index + 1,
                    totalSegments: total,
                    latestOutput: output,
                    isComplete: index + 1 == total
                )
                continuation.yield(progress)
            }
            if outputs.isEmpty {
                continuation.yield(SlicingProgress(
                    assetID: assetID,
                    completedSegments: 1,
                    totalSegments: 1,
                    latestOutput: nil,
                    isComplete: true
                ))
            }
            continuation.finish()
        }
    }

    func cancel(assetID: UUID) {
        cancelCallCount += 1
    }
}
