import Foundation

struct SliceSettings: Equatable {
    var maxSliceDuration: TimeInterval
    var resolution: VideoResolution
    var quality: VideoQuality

    var isValid: Bool {
        AppConstants.Slicing.durationRange.contains(maxSliceDuration)
    }

    static var `default`: SliceSettings {
        SliceSettings(
            maxSliceDuration: AppConstants.Slicing.defaultMaxDuration,
            resolution: AppConstants.Defaults.resolution,
            quality: AppConstants.Defaults.quality
        )
    }
}
