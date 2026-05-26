import Foundation

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    func targetBitrate(for resolution: VideoResolution) -> Int {
        switch (self, resolution) {
        case (.low, .p480):    return 500_000
        case (.low, .p720):    return 1_000_000
        case (.low, .p1080):   return 2_000_000
        case (.medium, .p480): return 1_500_000
        case (.medium, .p720): return 3_000_000
        case (.medium, .p1080):return 6_000_000
        case (.high, .p480):   return 3_000_000
        case (.high, .p720):   return 6_000_000
        case (.high, .p1080):  return 12_000_000
        }
    }
}
