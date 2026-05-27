import AVFoundation
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// GalleryService is @MainActor because pickerContinuation is mutated from the
// PHPickerViewControllerDelegate callback which must be on the main thread.
@MainActor
final class GalleryService: NSObject, GalleryServiceProtocol {

    private var pickerContinuation: CheckedContinuation<VideoAsset, Error>?

    func pickVideo(presentingViewController: UIViewController) async throws -> VideoAsset {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: GalleryError.exportFailed("Service deallocated"))
                return
            }
            self.pickerContinuation = continuation
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.filter = .videos
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            presentingViewController.present(picker, animated: true)
        }
    }
}

extension GalleryService: PHPickerViewControllerDelegate {

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            picker.dismiss(animated: true)

            guard let result = results.first else {
                pickerContinuation?.resume(throwing: GalleryError.cancelled)
                pickerContinuation = nil
                return
            }

            guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                pickerContinuation?.resume(throwing: GalleryError.unsupportedFormat)
                pickerContinuation = nil
                return
            }

            let assetIdentifier = result.assetIdentifier
            let itemProvider = result.itemProvider

            // Capture continuation before async work so it is not lost
            let continuation = pickerContinuation
            pickerContinuation = nil

            do {
                let asset = try await loadAndBuildAsset(
                    from: itemProvider,
                    assetIdentifier: assetIdentifier
                )
                continuation?.resume(returning: asset)
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }

    private func loadAndBuildAsset(
        from itemProvider: NSItemProvider,
        assetIdentifier: String?
    ) async throws -> VideoAsset {
        let stagedURL = try await loadAndStageInputFile(from: itemProvider)
        return try await buildVideoAsset(stagedURL: stagedURL, assetIdentifier: assetIdentifier)
    }

    private func loadAndStageInputFile(from itemProvider: NSItemProvider) async throws -> URL {
        // The URL from loadFileRepresentation is temporary and must be copied before
        // the callback returns, otherwise the system may delete it before AVFoundation opens it.
        try await Task.detached(priority: .userInitiated) {
            try await withCheckedThrowingContinuation { continuation in
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let error {
                        continuation.resume(throwing: GalleryError.exportFailed(error.localizedDescription))
                        return
                    }
                    guard let url else {
                        continuation.resume(throwing: GalleryError.exportFailed("No URL returned"))
                        return
                    }

                    do {
                        let stagedURL = try Self.stageInputFile(from: url)
                        continuation.resume(returning: stagedURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }.value
    }

    private static func stageInputFile(from url: URL) throws -> URL {
        let stagingDir = AppConstants.Paths.inputStagingDirectory
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let destination = stagingDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private func buildVideoAsset(stagedURL: URL, assetIdentifier: String?) async throws -> VideoAsset {
        let avAsset = AVURLAsset(url: stagedURL)

        // Use async load APIs to avoid deprecated synchronous AVAsset accessors
        async let durationTime = avAsset.load(.duration)
        async let videoTracks = avAsset.loadTracks(withMediaType: .video)

        let duration = CMTimeGetSeconds(try await durationTime)
        let tracks = try await videoTracks

        var originalSize = CGSize.zero
        if let track = tracks.first {
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformed = naturalSize.applying(transform)
            originalSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        // PHAsset.fetchAssets is a synchronous blocking call; dispatch to a background thread
        var creationDate: Date?
        if let identifier = assetIdentifier {
            creationDate = await Task.detached(priority: .userInitiated) {
                PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject?.creationDate
            }.value
        }

        return VideoAsset(
            id: UUID(),
            localIdentifier: assetIdentifier ?? stagedURL.lastPathComponent,
            url: stagedURL,
            filename: stagedURL.lastPathComponent,
            duration: max(duration, 0),
            creationDate: creationDate,
            originalSize: originalSize
        )
    }
}
