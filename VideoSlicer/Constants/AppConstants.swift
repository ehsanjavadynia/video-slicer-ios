import CoreGraphics
import Foundation

enum AppConstants {

    enum Slicing {
        static let defaultMaxDuration: TimeInterval = 30.0
        static let minimumSliceDuration: TimeInterval = 5.0
        static let maximumSliceDuration: TimeInterval = 600.0
        static let durationPresets: [TimeInterval] = [15, 30, 60, 120, 300]
        static let durationRange: ClosedRange<TimeInterval> = minimumSliceDuration...maximumSliceDuration
    }

    enum Paths {
        static var outputDirectory: URL {
            FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SlicedOutputs", isDirectory: true)
        }

        static var inputStagingDirectory: URL {
            FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("InputStaging", isDirectory: true)
        }
    }

    enum Export {
        // outputFileType (AVFileType) lives in VideoExportService to avoid
        // pulling AVFoundation into AppConstants.
        static let outputFileExtension = "mp4"
    }

    enum UI {
        static let thumbnailSize = CGSize(width: 120, height: 68)
        static let cornerRadius: CGFloat = 12.0
        static let animationDuration: Double = 0.25
        static let horizontalPadding: CGFloat = 20.0
        static let sectionSpacing: CGFloat = 24.0
    }

    enum Defaults {
        static let resolution: VideoResolution = .p720
        static let quality: VideoQuality = .medium
    }

    enum UITest {
        static let videoURLArgumentKey = "-UITestVideoURL"
    }
}
