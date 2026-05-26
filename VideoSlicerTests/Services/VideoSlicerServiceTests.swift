import AVFoundation
import Nimble
import Quick
@testable import VideoSlicer

final class VideoSlicerServiceTests: QuickSpec {
    override class func spec() {
        var sut: VideoSlicerService!
        var mockExport: MockVideoExportService!

        beforeEach {
            mockExport = MockVideoExportService()
            sut = VideoSlicerService(exportService: mockExport)
        }

        describe("computeTimeRanges(duration:maxSliceDuration:)") {
            it("produces 3 equal segments for 90s video with 30s max") {
                let ranges = sut.computeTimeRanges(duration: 90, maxSliceDuration: 30)
                expect(ranges).to(haveCount(3))
                expect(CMTimeGetSeconds(ranges[0].duration)).to(beCloseTo(30, within: 0.01))
                expect(CMTimeGetSeconds(ranges[1].duration)).to(beCloseTo(30, within: 0.01))
                expect(CMTimeGetSeconds(ranges[2].duration)).to(beCloseTo(30, within: 0.01))
            }

            it("produces 3 segments for 65s video with 30s max (last segment is 5s)") {
                let ranges = sut.computeTimeRanges(duration: 65, maxSliceDuration: 30)
                expect(ranges).to(haveCount(3))
                expect(CMTimeGetSeconds(ranges[0].duration)).to(beCloseTo(30, within: 0.01))
                expect(CMTimeGetSeconds(ranges[1].duration)).to(beCloseTo(30, within: 0.01))
                expect(CMTimeGetSeconds(ranges[2].duration)).to(beCloseTo(5, within: 0.01))
            }

            it("produces 1 segment when maxDuration exceeds video length") {
                let ranges = sut.computeTimeRanges(duration: 20, maxSliceDuration: 60)
                expect(ranges).to(haveCount(1))
                expect(CMTimeGetSeconds(ranges[0].duration)).to(beCloseTo(20, within: 0.01))
            }

            it("produces 1 segment for exact divisor") {
                let ranges = sut.computeTimeRanges(duration: 60, maxSliceDuration: 60)
                expect(ranges).to(haveCount(1))
                expect(CMTimeGetSeconds(ranges[0].duration)).to(beCloseTo(60, within: 0.01))
            }

            it("start times are sequential") {
                let ranges = sut.computeTimeRanges(duration: 90, maxSliceDuration: 30)
                expect(CMTimeGetSeconds(ranges[0].start)).to(beCloseTo(0, within: 0.01))
                expect(CMTimeGetSeconds(ranges[1].start)).to(beCloseTo(30, within: 0.01))
                expect(CMTimeGetSeconds(ranges[2].start)).to(beCloseTo(60, within: 0.01))
            }
        }

        describe("slice(asset:settings:)") {
            var testVideoURL: URL!

            beforeEach {
                let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("slicer_test_\(UUID().uuidString).mp4")
                try? TestVideoGenerator.generate(duration: 5, resolution: .p480, at: tmpURL)
                testVideoURL = tmpURL
                mockExport.stubbedOutputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("output_\(UUID().uuidString).mp4")
            }

            afterEach {
                try? FileManager.default.removeItem(at: testVideoURL)
            }

            it("throws zeroDuration for asset with zero duration") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 0)
                let settings = TestVideoGenerator.makeSliceSettings()
                await expect {
                    _ = try await sut.slice(asset: asset, settings: settings)
                }.to(throwError(SlicingError.zeroDuration))
            }

            it("throws invalidSettings for settings out of range") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 30)
                let settings = SliceSettings(maxSliceDuration: 0.1, resolution: .p720, quality: .medium)
                await expect {
                    _ = try await sut.slice(asset: asset, settings: settings)
                }.to(throwError(SlicingError.invalidSettings))
            }

            it("calls exportService correct number of times for 65s / 30s") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 65)
                let settings = TestVideoGenerator.makeSliceSettings(maxDuration: 30)

                let stream = try await sut.slice(asset: asset, settings: settings)
                var progressList: [SlicingProgress] = []
                for await progress in stream {
                    progressList.append(progress)
                }

                expect(mockExport.exportCallCount).to(equal(3))
                expect(progressList.last?.isComplete).to(beTrue())
                expect(progressList.last?.totalSegments).to(equal(3))
            }

            it("calls cancel without crashing") {
                let asset = TestVideoGenerator.makeVideoAsset(url: testVideoURL, duration: 30)
                sut.cancel(assetID: asset.id)
                // Should not crash
            }
        }
    }
}
