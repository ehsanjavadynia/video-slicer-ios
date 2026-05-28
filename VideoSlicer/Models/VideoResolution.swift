import AVFoundation
import CoreGraphics
import Foundation

enum VideoResolution: String, CaseIterable, Identifiable, Codable {
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .p1080: return "1080p (Full HD)"
        case .p720: return "720p (HD)"
        case .p480: return "480p (SD)"
        }
    }

    var shortLabel: String { rawValue }

    var targetSize: CGSize {
        switch self {
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p720: return CGSize(width: 1280, height: 720)
        case .p480: return CGSize(width: 854, height: 480)
        }
    }

    var avsExportPreset: String {
        switch self {
        case .p1080: return AVAssetExportPreset1920x1080
        case .p720: return AVAssetExportPreset1280x720
        case .p480: return AVAssetExportPresetMediumQuality
        }
    }
}
