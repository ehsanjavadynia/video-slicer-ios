import Nimble
import Quick
@testable import VideoSlicer

@MainActor
final class OutputViewModelTests: QuickSpec {
    override class func spec() {
        var sut: OutputViewModel!
        var mockThumbnail: MockVideoThumbnailService!

        beforeEach {
            mockThumbnail = MockVideoThumbnailService()
            sut = OutputViewModel(thumbnailService: mockThumbnail)
        }

        describe("loadOutputVideos") {
            it("groups videos by sourceAssetID") {
                let assetID1 = UUID()
                let assetID2 = UUID()
                let videos = [
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID1, sliceIndex: 1),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID1, sliceIndex: 2),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID2, sliceIndex: 1)
                ]

                sut.loadOutputVideos(videos)

                expect(sut.videoGroups).to(haveCount(2))
                let group1 = sut.videoGroups.first { $0.id == assetID1 }
                expect(group1?.videos).to(haveCount(2))
                let group2 = sut.videoGroups.first { $0.id == assetID2 }
                expect(group2?.videos).to(haveCount(1))
            }

            it("sorts clips within group by sliceIndex") {
                let assetID = UUID()
                let videos = [
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 3),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 1),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 2)
                ]

                sut.loadOutputVideos(videos)

                guard let group = sut.videoGroups.first else {
                    fail("Expected at least one video group")
                    return
                }
                expect(group.videos[0].sliceIndex).to(equal(1))
                expect(group.videos[1].sliceIndex).to(equal(2))
                expect(group.videos[2].sliceIndex).to(equal(3))
            }

            it("handles empty input") {
                sut.loadOutputVideos([])
                expect(sut.videoGroups).to(beEmpty())
            }
        }

        describe("toggleSelection") {
            it("adds videoID when not selected") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])

                sut.toggleSelection(videoID: video.id)

                expect(sut.selectedVideoIDs).to(contain(video.id))
            }

            it("removes videoID when already selected") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])
                sut.selectedVideoIDs.insert(video.id)

                sut.toggleSelection(videoID: video.id)

                expect(sut.selectedVideoIDs).notTo(contain(video.id))
            }
        }

        describe("selectAll(in:)") {
            it("selects all videos in a group") {
                let assetID = UUID()
                let videos = [
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 1),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 2)
                ]
                sut.loadOutputVideos(videos)

                sut.selectAll(in: assetID)

                expect(sut.selectedVideoIDs).to(haveCount(2))
            }
        }

        describe("clearSelection") {
            it("empties selectedVideoIDs") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])
                sut.selectedVideoIDs.insert(video.id)

                sut.clearSelection()

                expect(sut.selectedVideoIDs).to(beEmpty())
            }
        }

        describe("clearOutputVideos") {
            it("clears videos, selection, share items, and share sheet state") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])
                sut.selectedVideoIDs.insert(video.id)
                sut.shareItems = [video.url]
                sut.isShareSheetPresented = true

                sut.clearOutputVideos()

                expect(sut.videoGroups).to(beEmpty())
                expect(sut.selectedVideoIDs).to(beEmpty())
                expect(sut.shareItems).to(beEmpty())
                expect(sut.isShareSheetPresented).to(beFalse())
            }
        }

        describe("shareSelectedTapped") {
            it("sets shareItems to URLs of selected videos") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])
                sut.selectedVideoIDs.insert(video.id)

                sut.shareSelectedTapped()

                expect(sut.shareItems).to(haveCount(1))
                expect(sut.isShareSheetPresented).to(beTrue())
            }

            it("does nothing when no videos selected") {
                let video = TestVideoGenerator.makeOutputVideo()
                sut.loadOutputVideos([video])

                sut.shareSelectedTapped()

                expect(sut.shareItems).to(beEmpty())
            }
        }

        describe("VideoGroup computed properties") {
            it("displayCount returns correct string") {
                let assetID = UUID()
                let videos = [
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 1),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 2)
                ]
                sut.loadOutputVideos(videos)

                guard let group = sut.videoGroups.first else {
                    fail("Expected at least one video group")
                    return
                }
                expect(group.displayCount).to(equal("2 clips"))
            }

            it("totalDuration sums clip durations") {
                let assetID = UUID()
                let videos = [
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 1, duration: 30),
                    TestVideoGenerator.makeOutputVideo(sourceAssetID: assetID, sliceIndex: 2, duration: 5)
                ]
                sut.loadOutputVideos(videos)

                guard let group = sut.videoGroups.first else {
                    fail("Expected at least one video group")
                    return
                }
                expect(group.totalDuration).to(beCloseTo(35, within: 0.01))
            }
        }
    }
}
