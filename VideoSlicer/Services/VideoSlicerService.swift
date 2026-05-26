import AVFoundation
import Foundation

final class VideoSlicerService: VideoSlicerServiceProtocol {

    private let exportService: VideoExportServiceProtocol
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(exportService: VideoExportServiceProtocol) {
        self.exportService = exportService
    }

    func slice(
        asset: VideoAsset,
        settings: SliceSettings
    ) async throws -> AsyncStream<SlicingProgress> {
        guard asset.duration > 0 else { throw SlicingError.zeroDuration }
        guard settings.isValid else { throw SlicingError.invalidSettings }

        try prepareOutputDirectory()

        let avAsset = AVURLAsset(url: asset.url)
        let timeRanges = computeTimeRanges(duration: asset.duration, maxSliceDuration: settings.maxSliceDuration)
        let total = timeRanges.count

        let stream = AsyncStream<SlicingProgress> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let task = Task {
                for (index, range) in timeRanges.enumerated() {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    let outputURL = self.outputURL(for: asset, sliceIndex: index + 1, settings: settings)
                    do {
                        let resultURL = try await self.exportService.export(
                            avAsset: avAsset,
                            timeRange: range,
                            outputURL: outputURL,
                            resolution: settings.resolution,
                            quality: settings.quality
                        )
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: resultURL.path)[.size] as? Int64) ?? 0
                        let sliceDuration = CMTimeGetSeconds(range.duration)
                        let output = OutputVideo(
                            id: UUID(),
                            sourceAssetID: asset.id,
                            sourceFilename: asset.filename,
                            url: resultURL,
                            sliceIndex: index + 1,
                            duration: sliceDuration,
                            resolution: settings.resolution,
                            quality: settings.quality,
                            fileSize: fileSize,
                            createdAt: Date()
                        )
                        let progress = SlicingProgress(
                            assetID: asset.id,
                            completedSegments: index + 1,
                            totalSegments: total,
                            latestOutput: output,
                            isComplete: index + 1 == total
                        )
                        continuation.yield(progress)
                    } catch {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
            self.activeTasks[asset.id] = task
            continuation.onTermination = { [weak self] _ in
                self?.activeTasks.removeValue(forKey: asset.id)
            }
        }
        return stream
    }

    func cancel(assetID: UUID) {
        activeTasks[assetID]?.cancel()
        activeTasks.removeValue(forKey: assetID)
    }

    func computeTimeRanges(duration: TimeInterval, maxSliceDuration: TimeInterval) -> [CMTimeRange] {
        var ranges: [CMTimeRange] = []
        var currentTime: TimeInterval = 0
        while currentTime < duration {
            let segmentDuration = min(maxSliceDuration, duration - currentTime)
            let start = CMTime(seconds: currentTime, preferredTimescale: 600)
            let length = CMTime(seconds: segmentDuration, preferredTimescale: 600)
            ranges.append(CMTimeRange(start: start, duration: length))
            currentTime += segmentDuration
        }
        return ranges
    }

    private func outputURL(for asset: VideoAsset, sliceIndex: Int, settings: SliceSettings) -> URL {
        let base = (asset.filename as NSString).deletingPathExtension
        let filename = String(format: "%@_clip_%03d.%@", base, sliceIndex, AppConstants.Export.outputFileExtension)
        return AppConstants.Paths.outputDirectory
            .appendingPathComponent(asset.id.uuidString)
            .appendingPathComponent(filename)
    }

    private func prepareOutputDirectory() throws {
        let dir = AppConstants.Paths.outputDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw SlicingError.outputDirectoryFailed
        }
    }
}
