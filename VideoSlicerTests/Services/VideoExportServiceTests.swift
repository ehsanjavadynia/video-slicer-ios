import AVFoundation
import Nimble
import Quick
@testable import VideoSlicer

final class VideoExportServiceTests: QuickSpec {
    override class func spec() {
        var sut: VideoExportService!

        beforeEach {
            sut = VideoExportService()
        }

        describe("outputFileExtension") {
            it("returns mp4") {
                expect(sut.outputFileExtension).to(equal("mp4"))
            }
        }

        describe("export(avAsset:timeRange:outputURL:resolution:quality:)") {
            var testVideoURL: URL!
            var outputURL: URL!

            beforeEach {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
                testVideoURL = tmpDir.appendingPathComponent("export_test_\(UUID().uuidString).mp4")
                outputURL = tmpDir.appendingPathComponent("export_out_\(UUID().uuidString).mp4")
                try? TestVideoGenerator.generate(duration: 5, resolution: .p480, at: testVideoURL)
            }

            afterEach {
                try? FileManager.default.removeItem(at: testVideoURL)
                try? FileManager.default.removeItem(at: outputURL)
            }

            it("creates output file for valid 480p export") {
                let avAsset = AVURLAsset(url: testVideoURL)
                let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))

                await expect {
                    try await sut.export(
                        avAsset: avAsset,
                        timeRange: timeRange,
                        outputURL: outputURL,
                        resolution: .p480,
                        quality: .medium
                    )
                }.notTo(throwError())

                expect(FileManager.default.fileExists(atPath: outputURL.path)).to(beTrue())
            }

            it("throws exportFailed for missing source file") {
                let fakeURL = URL(fileURLWithPath: "/nonexistent/path/video.mp4")
                let avAsset = AVURLAsset(url: fakeURL)
                let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))

                await expect {
                    try await sut.export(
                        avAsset: avAsset,
                        timeRange: timeRange,
                        outputURL: outputURL,
                        resolution: .p720,
                        quality: .medium
                    )
                }.to(throwError())
            }

            it("auto-creates output subdirectory") {
                let deepURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("nested/deep/dir/\(UUID().uuidString)")
                    .appendingPathComponent("output.mp4")
                let avAsset = AVURLAsset(url: testVideoURL)
                let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600))

                await expect {
                    try await sut.export(
                        avAsset: avAsset,
                        timeRange: timeRange,
                        outputURL: deepURL,
                        resolution: .p480,
                        quality: .low
                    )
                }.notTo(throwError())

                try? FileManager.default.removeItem(at: deepURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
            }
        }
    }
}
