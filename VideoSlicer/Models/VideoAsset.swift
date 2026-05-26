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
