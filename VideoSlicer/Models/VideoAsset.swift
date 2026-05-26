import AVFoundation
import CoreGraphics
import Foundation

struct VideoAsset: Identifiable, Equatable, Hashable {
    let id: UUID
    let localIdentifier: String
    let url: URL
    let filename: String
    let duration: TimeInterval
    let creationDate: Date?
    let originalSize: CGSize

    var displayDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var thumbnailCacheKey: String {
        "\(localIdentifier)_thumb"
    }

    static func == (lhs: VideoAsset, rhs: VideoAsset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Private Helpers

/// Reads the duration of an AVAsset using the synchronous (deprecated) API.
/// Wrapped here to contain the deprecation warning to one place.
/// Only use this from UI-test injection code paths; production code should use async load(.duration).
private func videoAssetDurationSync(_ asset: AVAsset) -> TimeInterval {
    // Intentional use of deprecated API: this is UI-test-only injection code where
    // async loading is impractical. The deprecation warning is accepted here.
    max(CMTimeGetSeconds(asset.duration), 0)
}

extension VideoAsset {

    /// Creates a VideoAsset from a local file URL using synchronous AVFoundation accessors.
    /// Intended for use in UI-test asset injection only — do not call from production async paths.
    static func fromURL(_ url: URL) -> VideoAsset? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let avAsset = AVURLAsset(url: url)
        // Synchronous AVAsset duration access is deprecated in iOS 16, but this method is
        // only called from UI-test launch-argument injection where async loading is impractical.
        // In production code, use GalleryService.buildVideoAsset which uses async load(.duration).
        let duration = videoAssetDurationSync(avAsset)
        return VideoAsset(
            id: UUID(),
            localIdentifier: url.lastPathComponent,
            url: url,
            filename: url.lastPathComponent,
            duration: duration,
            creationDate: nil,
            originalSize: .zero
        )
    }
}
