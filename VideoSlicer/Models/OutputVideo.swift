import Foundation

struct OutputVideo: Identifiable, Equatable {
    let id: UUID
    let sourceAssetID: UUID
    let sourceFilename: String
    let url: URL
    let sliceIndex: Int
    let duration: TimeInterval
    let resolution: VideoResolution
    let quality: VideoQuality
    let fileSize: Int64
    let createdAt: Date

    var displayName: String {
        let base = (sourceFilename as NSString).deletingPathExtension
        return String(format: "%@_clip_%03d.mp4", base, sliceIndex)
    }

    var displayDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var displayFileSize: String {
        let mb = Double(fileSize) / 1_048_576
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(fileSize) / 1024
        return String(format: "%.0f KB", kb)
    }
}
