import Combine
import Nimble
import Quick
import UIKit
@testable import VideoSlicer

@MainActor
final class MainViewModelTests: QuickSpec {
    override class func spec() {
        var sut: MainViewModel!
        var mockGallery: MockGalleryService!
        var mockSlicer: MockVideoSlicerService!

        beforeEach {
            mockGallery = MockGalleryService()
            mockSlicer = MockVideoSlicerService()
            sut = MainViewModel(galleryService: mockGallery, slicerService: mockSlicer)
        }

        describe("initial state") {
            it("has no selected asset") {
                expect(sut.selectedAsset).to(beNil())
            }

            it("has default slice settings") {
                expect(sut.sliceSettings.maxSliceDuration).to(equal(AppConstants.Slicing.defaultMaxDuration))
                expect(sut.sliceSettings.resolution).to(equal(AppConstants.Defaults.resolution))
                expect(sut.sliceSettings.quality).to(equal(AppConstants.Defaults.quality))
            }

            it("canStartSlicing is false with no asset") {
                expect(sut.canStartSlicing).to(beFalse())
            }
        }

        describe("pickVideoTapped") {
            it("sets selectedAsset on success") {
                let asset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 60
                )
                mockGallery.stubbedAsset = asset

                await sut.pickVideoTapped(presentingViewController: UIViewController())

                expect(sut.selectedAsset).to(equal(asset))
            }

            it("sets no error on gallery cancel") {
                mockGallery.shouldThrow = true
                mockGallery.thrownError = .cancelled

                await sut.pickVideoTapped(presentingViewController: UIViewController())

                expect(sut.errorMessage).to(beNil())
            }

            it("sets errorMessage on gallery error") {
                mockGallery.shouldThrow = true
                mockGallery.thrownError = .permissionDenied

                await sut.pickVideoTapped(presentingViewController: UIViewController())

                expect(sut.errorMessage).notTo(beNil())
            }

            it("sets isPickingVideo to false after completion") {
                mockGallery.stubbedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 30
                )

                await sut.pickVideoTapped(presentingViewController: UIViewController())

                expect(sut.isPickingVideo).to(beFalse())
            }
        }

        describe("canStartSlicing") {
            it("returns false when isSlicing is true") {
                sut.selectedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 30
                )
                sut.isSlicing = true
                expect(sut.canStartSlicing).to(beFalse())
            }

            it("returns true with valid asset and settings") {
                sut.selectedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 60
                )
                expect(sut.canStartSlicing).to(beTrue())
            }

            it("returns false with invalid settings (slice duration below minimum)") {
                sut.selectedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 60
                )
                sut.sliceSettings = SliceSettings(maxSliceDuration: 1, resolution: .p720, quality: .medium)
                expect(sut.canStartSlicing).to(beFalse())
            }
        }

        describe("estimatedSegmentCount") {
            it("returns ceil(duration / maxSliceDuration)") {
                sut.selectedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 65
                )
                sut.sliceSettings = SliceSettings(maxSliceDuration: 30, resolution: .p720, quality: .medium)
                expect(sut.estimatedSegmentCount).to(equal(3))
            }

            it("returns 0 when no asset selected") {
                expect(sut.estimatedSegmentCount).to(equal(0))
            }
        }

        describe("startSlicingTapped") {
            var asset: VideoAsset!

            beforeEach {
                asset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 65
                )
                sut.selectedAsset = asset
            }

            it("appends outputVideos as segments complete") {
                let output = TestVideoGenerator.makeOutputVideo(sourceAssetID: asset.id)
                mockSlicer.stubbedOutputVideos = [output]

                await sut.startSlicingTapped()

                expect(sut.outputVideos).to(haveCount(1))
            }

            it("sets navigateToOutput to true on completion") {
                mockSlicer.stubbedOutputVideos = [TestVideoGenerator.makeOutputVideo(sourceAssetID: asset.id)]

                await sut.startSlicingTapped()

                expect(sut.navigateToOutput).to(beTrue())
            }

            it("sets isSlicing to false after completion") {
                await sut.startSlicingTapped()
                expect(sut.isSlicing).to(beFalse())
            }

            it("sets errorMessage when slicing throws") {
                mockSlicer.shouldThrow = true

                await sut.startSlicingTapped()

                expect(sut.errorMessage).notTo(beNil())
                expect(sut.isSlicing).to(beFalse())
            }
        }

        describe("cancelSlicing") {
            it("clears slicing state") {
                sut.selectedAsset = TestVideoGenerator.makeVideoAsset(
                    url: URL(fileURLWithPath: "/tmp/test.mp4"),
                    duration: 60
                )
                sut.slicingProgress = 0.5
                sut.slicingProgressText = "Exporting 1 of 2..."

                sut.cancelSlicing()

                expect(sut.isSlicing).to(beFalse())
                expect(sut.slicingProgress).to(equal(0))
                expect(sut.slicingProgressText).to(equal(""))
                expect(sut.outputVideos).to(beEmpty())
                expect(mockSlicer.cancelCallCount).to(equal(1))
            }

            it("does nothing when no asset selected") {
                sut.selectedAsset = nil
                // Should not crash
                sut.cancelSlicing()
                expect(sut.isSlicing).to(beFalse())
            }
        }

        describe("deleteOutputVideos") {
            it("removes output files and clears outputVideos") {
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                try? Data("clip".utf8).write(to: fileURL)
                sut.outputVideos = [TestVideoGenerator.makeOutputVideo(url: fileURL)]

                sut.deleteOutputVideos()

                expect(sut.outputVideos).to(beEmpty())
                expect(FileManager.default.fileExists(atPath: fileURL.path)).to(beFalse())
            }
        }

        describe("clearError") {
            it("clears errorMessage") {
                sut.errorMessage = "Some error"
                sut.clearError()
                expect(sut.errorMessage).to(beNil())
            }
        }
    }
}
