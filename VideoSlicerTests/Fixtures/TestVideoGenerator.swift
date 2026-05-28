import AVFoundation
import CoreGraphics
import Foundation
@testable import VideoSlicer

enum TestVideoGenerator {

    static func generate(duration: TimeInterval, resolution: VideoResolution = .p720, at url: URL) throws -> URL {
        let size = resolution.targetSize
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frameCount = Int(duration * Double(fps))
        let frameDuration = CMTime(value: 1, timescale: fps)

        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            let presentTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)
            if let buffer = makePixelBuffer(size: size, frameIndex: frameIndex) {
                adaptor.append(buffer, withPresentationTime: presentTime)
            }
            _ = frameDuration
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        var writeError: Error?
        writer.finishWriting {
            if writer.status == .failed {
                writeError = writer.error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let error = writeError {
            throw error
        }

        return url
    }

    private static func makePixelBuffer(size: CGSize, frameIndex: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let hue = CGFloat(frameIndex % 360) / 360.0
        let color = UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let blueVal = UInt8(b * 255)
        let greenVal = UInt8(g * 255)
        let redVal = UInt8(r * 255)

        let totalBytes = bytesPerRow * Int(size.height)
        if let base = baseAddress {
            let pixels = base.bindMemory(to: UInt8.self, capacity: totalBytes)
            for i in stride(from: 0, to: totalBytes, by: 4) {
                pixels[i] = blueVal
                pixels[i + 1] = greenVal
                pixels[i + 2] = redVal
                pixels[i + 3] = 255
            }
        }
        return buffer
    }
}

extension TestVideoGenerator {

    static func makeVideoAsset(url: URL, duration: TimeInterval, filename: String? = nil) -> VideoAsset {
        VideoAsset(
            id: UUID(),
            localIdentifier: url.lastPathComponent,
            url: url,
            filename: filename ?? url.lastPathComponent,
            duration: duration,
            creationDate: Date(),
            originalSize: CGSize(width: 1280, height: 720),
            avAsset: AVURLAsset(url: url)
        )
    }

    static func makeSliceSettings(
        maxDuration: TimeInterval = 30,
        resolution: VideoResolution = .p720,
        quality: VideoQuality = .medium
    ) -> SliceSettings {
        SliceSettings(maxSliceDuration: maxDuration, resolution: resolution, quality: quality)
    }

    static func makeOutputVideo(
        sourceAssetID: UUID = UUID(),
        sliceIndex: Int = 1,
        duration: TimeInterval = 30,
        url: URL? = nil
    ) -> OutputVideo {
        OutputVideo(
            id: UUID(),
            sourceAssetID: sourceAssetID,
            sourceFilename: "test_video.mp4",
            url: url ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clip_\(sliceIndex).mp4"),
            sliceIndex: sliceIndex,
            duration: duration,
            resolution: .p720,
            quality: .medium,
            fileSize: 1024 * 1024,
            createdAt: Date()
        )
    }
}
