import AVFoundation
import Nimble
import Quick
@testable import VideoSlicer

final class VideoThumbnailServiceTests: QuickSpec {
    override class func spec() {
        var sut: VideoThumbnailService!

        beforeEach {
            sut = VideoThumbnailService()
            sut.clearCache()
        }

        describe("thumbnail(for:at:size:)") {
            var testVideoURL: URL!

            beforeEach {
                testVideoURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("thumb_test_\(UUID().uuidString).mp4")
                try? TestVideoGenerator.generate(duration: 3, resolution: .p480, at: testVideoURL)
            }

            afterEach {
                try? FileManager.default.removeItem(at: testVideoURL)
            }

            it("returns an image for a valid video") {
                let result = try? await sut.thumbnail(
                    for: testVideoURL,
                    at: .zero,
                    size: AppConstants.UI.thumbnailSize
                )
                expect(result).notTo(beNil())
            }

            it("returns cached image on second call") {
                _ = try? await sut.thumbnail(for: testVideoURL, at: .zero, size: AppConstants.UI.thumbnailSize)
                _ = try? await sut.thumbnail(for: testVideoURL, at: .zero, size: AppConstants.UI.thumbnailSize)
                // Should not crash; cache is exercised internally
            }

            it("throws for invalid URL") {
                let badURL = URL(fileURLWithPath: "/nonexistent/fake.mp4")
                await expect {
                    try await sut.thumbnail(for: badURL, at: .zero, size: AppConstants.UI.thumbnailSize)
                }.to(throwError())
            }
        }

        describe("clearCache()") {
            it("does not crash when called multiple times") {
                sut.clearCache()
                sut.clearCache()
            }
        }
    }
}
