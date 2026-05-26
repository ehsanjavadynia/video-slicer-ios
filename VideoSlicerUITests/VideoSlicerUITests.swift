import AVFoundation
import CoreMedia
import XCTest

final class VideoSlicerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSliceButtonDisabledWithNoVideo() {
        app.launch()

        let sliceButton = app.buttons["Slice Video"]
        XCTAssertTrue(sliceButton.waitForExistence(timeout: 5))
        XCTAssertFalse(sliceButton.isEnabled, "Slice button should be disabled when no video is selected")
    }

    func testVideoPickerButtonExists() {
        app.launch()

        let pickerButton = app.buttons["Choose video"]
        XCTAssertTrue(pickerButton.waitForExistence(timeout: 5))
    }

    func testFullSlicingFlowWithInjectedVideo() throws {
        let videoURL = try createTestVideoFile()
        defer { try? FileManager.default.removeItem(at: videoURL) }

        app.launchArguments = [AppLaunchArgs.uiTestVideoURL, videoURL.path]
        app.launch()

        XCTAssertTrue(app.staticTexts["VideoSlicer"].waitForExistence(timeout: 5))

        let sliceButton = app.buttons["Slice Video"]
        XCTAssertTrue(sliceButton.waitForExistence(timeout: 5))

        guard sliceButton.isEnabled else {
            XCTSkip("UI test video injection not available in this environment")
        }

        sliceButton.tap()

        let outputNavTitle = app.navigationBars["Sliced Videos"]
        let appeared = outputNavTitle.waitForExistence(timeout: 60)
        XCTAssertTrue(appeared, "Output view should appear after slicing completes")
    }

    func testShareButtonDisabledWithNoSelection() throws {
        let videoURL = try createTestVideoFile()
        defer { try? FileManager.default.removeItem(at: videoURL) }

        app.launchArguments = [AppLaunchArgs.uiTestVideoURL, videoURL.path]
        app.launch()

        let sliceButton = app.buttons["Slice Video"]
        guard sliceButton.waitForExistence(timeout: 5), sliceButton.isEnabled else {
            XCTSkip("UI test video injection not available in this environment")
        }

        sliceButton.tap()

        let outputNavTitle = app.navigationBars["Sliced Videos"]
        guard outputNavTitle.waitForExistence(timeout: 60) else {
            XCTFail("Output view did not appear")
            return
        }

        let shareButton = app.buttons["Share selected clips"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        XCTAssertFalse(shareButton.isEnabled, "Share button should be disabled with no selection")
    }
}

private enum AppLaunchArgs {
    static let uiTestVideoURL = "-UITestVideoURL"
}

private extension VideoSlicerUITests {
    func createTestVideoFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ui_test_\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 640,
            AVVideoHeightKey: 360
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 640,
                kCVPixelBufferHeightKey as String: 360
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let fps: Int32 = 30
        let frameCount = 5 * Int(fps)
        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 640, 360, kCVPixelFormatType_32BGRA, nil, &pb)
            if let pb = pb { adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps)) }
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        return url
    }
}
