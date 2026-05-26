import AVFoundation
import Foundation
@testable import VideoSlicer

final class MockVideoExportService: VideoExportServiceProtocol {

    var exportCallCount = 0
    var stubbedOutputURL: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mock_output.mp4")
    var shouldThrow = false
    var capturedTimeRanges: [CMTimeRange] = []
    var capturedResolutions: [VideoResolution] = []
    var capturedQualities: [VideoQuality] = []

    var outputFileExtension: String { "mp4" }

    func export(
        avAsset: AVAsset,
        timeRange: CMTimeRange,
        outputURL: URL,
        resolution: VideoResolution,
        quality: VideoQuality
    ) async throws -> URL {
        exportCallCount += 1
        capturedTimeRanges.append(timeRange)
        capturedResolutions.append(resolution)
        capturedQualities.append(quality)

        if shouldThrow {
            throw ExportError.exportFailed("Mock error")
        }

        return stubbedOutputURL
    }
}
