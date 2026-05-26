import AVFoundation
import Nimble
import Quick
@testable import VideoSlicer

final class SlicingIntegrationTests: QuickSpec {
    override class func spec() {
        describe("Full slicing pipeline (VideoSlicerService + VideoExportService)") {
            var slicerService: VideoSlicerService!
            var exportService: VideoExportService!
            var testVideoURL: URL!
            var outputURLs: [URL] = []

            beforeEach {
                exportService = VideoExportService()
                slicerService = VideoSlicerService(exportService: exportService)
                outputURLs = []

                testVideoURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("integration_test_\(UUID().uuidString).mp4")

                try? TestVideoGenerator.generate(duration: 65, resolution: .p480, at: testVideoURL)
            }

            afterEach {
                try? FileManager.default.removeItem(at: testVideoURL)
                for url in outputURLs {
                    try? FileManager.default.removeItem(at: url)
                }
                let outputDir = AppConstants.Paths.outputDirectory
                try? FileManager.default.removeItem(at: outputDir)
            }

            it("produces 3 segments from 65s video with 30s max duration") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 65)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30, resolution: .p480)

                let stream = try await slicerService.slice(asset: asset, settings: settings)
                var outputs: [OutputVideo] = []
                for await progress in stream {
                    if let output = progress.latestOutput {
                        outputs.append(output)
                        outputURLs.append(output.url)
                    }
                }

                expect(outputs).to(haveCount(3))
            }

            it("all output files exist on disk") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 65)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30, resolution: .p480)

                let stream = try await slicerService.slice(asset: asset, settings: settings)
                var outputs: [OutputVideo] = []
                for await progress in stream {
                    if let output = progress.latestOutput {
                        outputs.append(output)
                        outputURLs.append(output.url)
                    }
                }

                for output in outputs {
                    expect(FileManager.default.fileExists(atPath: output.url.path)).to(beTrue())
                }
            }

            it("segment durations are approximately correct") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 65)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30, resolution: .p480)

                let stream = try await slicerService.slice(asset: asset, settings: settings)
                var outputs: [OutputVideo] = []
                for await progress in stream {
                    if let output = progress.latestOutput {
                        outputs.append(output)
                        outputURLs.append(output.url)
                    }
                }

                expect(outputs[0].duration).to(beCloseTo(30, within: 1.5))
                expect(outputs[1].duration).to(beCloseTo(30, within: 1.5))
                expect(outputs[2].duration).to(beCloseTo(5, within: 1.5))
            }

            it("segments are in correct order by sliceIndex") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 65)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30, resolution: .p480)

                let stream = try await slicerService.slice(asset: asset, settings: settings)
                var outputs: [OutputVideo] = []
                for await progress in stream {
                    if let output = progress.latestOutput {
                        outputs.append(output)
                        outputURLs.append(output.url)
                    }
                }

                expect(outputs[0].sliceIndex).to(equal(1))
                expect(outputs[1].sliceIndex).to(equal(2))
                expect(outputs[2].sliceIndex).to(equal(3))
            }

            it("produces 1 segment when video shorter than maxDuration") {
                let shortVideoURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("short_\(UUID().uuidString).mp4")
                try? TestVideoGenerator.generate(duration: 10, resolution: .p480, at: shortVideoURL)
                defer { try? FileManager.default.removeItem(at: shortVideoURL) }

                let asset = TestVideoGenerator.makeVideoAsset(url: shortVideoURL, duration: 10)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30, resolution: .p480)

                let stream = try await slicerService.slice(asset: asset, settings: settings)
                var outputs: [OutputVideo] = []
                for await progress in stream {
                    if let output = progress.latestOutput {
                        outputs.append(output)
                        outputURLs.append(output.url)
                    }
                }

                expect(outputs).to(haveCount(1))
            }
        }
    }
}
