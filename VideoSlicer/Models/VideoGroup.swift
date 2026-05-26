import Foundation

struct VideoGroup: Identifiable, Equatable {
    let id: UUID
    let sourceFilename: String
    let videos: [OutputVideo]

    var totalDuration: TimeInterval {
        videos.reduce(0) { $0 + $1.duration }
    }

    var displayCount: String {
        "\(videos.count) clip\(videos.count == 1 ? "" : "s")"
    }

    var displaySourceName: String {
        (sourceFilename as NSString).deletingPathExtension
    }
}
