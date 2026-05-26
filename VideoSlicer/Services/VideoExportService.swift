import AVFoundation
import Foundation

final class VideoExportService: VideoExportServiceProtocol {

    var outputFileExtension: String { AppConstants.Export.outputFileExtension }

    func export(
        avAsset: AVAsset,
        timeRange: CMTimeRange,
        outputURL: URL,
        resolution: VideoResolution,
        quality: VideoQuality
    ) async throws -> URL {
        try createOutputDirectoryIfNeeded(for: outputURL)

        let preset = exportPreset(for: resolution, quality: quality)
        guard let session = AVAssetExportSession(asset: avAsset, presetName: preset) else {
            throw ExportError.exportSessionCreationFailed
        }

        session.outputURL = outputURL
        session.outputFileType = AppConstants.Export.outputFileType
        session.timeRange = timeRange
        session.shouldOptimizeForNetworkUse = true

        await session.export()

        switch session.status {
        case .completed:
            return outputURL
        case .cancelled:
            throw ExportError.cancelled
        case .failed:
            throw ExportError.exportFailed(session.error?.localizedDescription ?? "Unknown error")
        default:
            throw ExportError.exportFailed("Unexpected export status: \(session.status.rawValue)")
        }
    }

    private func exportPreset(for resolution: VideoResolution, quality: VideoQuality) -> String {
        switch (resolution, quality) {
        case (.p1080, .high): return AVAssetExportPreset1920x1080
        case (.p1080, .medium): return AVAssetExportPreset1920x1080
        case (.p1080, .low): return AVAssetExportPreset1280x720
        case (.p720, .high): return AVAssetExportPreset1280x720
        case (.p720, .medium): return AVAssetExportPreset1280x720
        case (.p720, .low): return AVAssetExportPresetMediumQuality
        case (.p480, _): return AVAssetExportPresetMediumQuality
        }
    }

    private func createOutputDirectoryIfNeeded(for url: URL) throws {
        let directory = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw ExportError.exportFailed("Could not create output directory: \(error.localizedDescription)")
            }
        }
    }
}
