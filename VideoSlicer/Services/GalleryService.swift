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
    private var progressHandler: (@MainActor @Sendable (Double) -> Void)?

    func pickVideo(
        presentingViewController: UIViewController,
        onProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> VideoAsset {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: GalleryError.exportFailed("Service deallocated"))
                return
            }
            self.pickerContinuation = continuation
            self.progressHandler = onProgress
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
                progressHandler = nil
                return
            }

            guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                pickerContinuation?.resume(throwing: GalleryError.unsupportedFormat)
                pickerContinuation = nil
                progressHandler = nil
                return
            }

            let assetIdentifier = result.assetIdentifier
            let itemProvider = result.itemProvider
            let onProgress = progressHandler

            // Capture continuation before async work so it is not lost
            let continuation = pickerContinuation
            pickerContinuation = nil
            progressHandler = nil

            do {
                let asset = try await loadAndBuildAsset(
                    from: itemProvider,
                    assetIdentifier: assetIdentifier,
                    onProgress: onProgress
                )
                continuation?.resume(returning: asset)
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }

    /// Build a VideoAsset from the picker result. Prefers PHImageManager (no copy,
    /// surfaces iCloud download progress); falls back to the legacy
    /// loadFileRepresentation copy path if the asset can't be served that way.
    private func loadAndBuildAsset(
        from itemProvider: NSItemProvider,
        assetIdentifier: String?,
        onProgress: (@MainActor @Sendable (Double) -> Void)?
    ) async throws -> VideoAsset {
        if let assetIdentifier,
           let asset = try? await buildAssetViaPhotosLibrary(
               assetIdentifier: assetIdentifier,
               onProgress: onProgress
           ) {
            return asset
        }
        let stagedURL = try await loadAndStageInputFile(from: itemProvider)
        return try await buildVideoAsset(
            avAsset: AVURLAsset(url: stagedURL),
            url: stagedURL,
            filename: stagedURL.lastPathComponent,
            localIdentifier: assetIdentifier ?? stagedURL.lastPathComponent,
            assetIdentifier: assetIdentifier
        )
    }

    /// Uses PHImageManager to obtain an AVAsset for the picked PHAsset without
    /// copying the file into the app sandbox. Surfaces iCloud download progress.
    private func buildAssetViaPhotosLibrary(
        assetIdentifier: String,
        onProgress: (@MainActor @Sendable (Double) -> Void)?
    ) async throws -> VideoAsset {
        let phAsset: PHAsset = try await Task.detached(priority: .userInitiated) {
            guard let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
                throw GalleryError.exportFailed("Asset not found in Photos library")
            }
            return result
        }.value

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.progressHandler = { progress, _, _, _ in
            Task { @MainActor in onProgress?(progress) }
        }

        let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: GalleryError.exportFailed(error.localizedDescription))
                    return
                }
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: GalleryError.cancelled)
                    return
                }
                guard let asset else {
                    continuation.resume(throwing: GalleryError.exportFailed("No AVAsset returned"))
                    return
                }
                continuation.resume(returning: asset)
            }
        }

        let url = (avAsset as? AVURLAsset)?.url
        let filename = phAssetFilename(phAsset) ?? url?.lastPathComponent ?? assetIdentifier

        return try await buildVideoAsset(
            avAsset: avAsset,
            url: url ?? URL(fileURLWithPath: "/dev/null"),
            filename: filename,
            localIdentifier: assetIdentifier,
            assetIdentifier: assetIdentifier,
            creationDate: phAsset.creationDate
        )
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

    nonisolated private static func stageInputFile(from url: URL) throws -> URL {
        let stagingDir = AppConstants.Paths.inputStagingDirectory
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let destination = stagingDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private func buildVideoAsset(
        avAsset: AVAsset,
        url: URL,
        filename: String,
        localIdentifier: String,
        assetIdentifier: String?,
        creationDate: Date? = nil
    ) async throws -> VideoAsset {
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

        // Fetch creation date if not already provided and we have an asset identifier
        var resolvedCreationDate = creationDate
        if resolvedCreationDate == nil, let identifier = assetIdentifier {
            resolvedCreationDate = await Task.detached(priority: .userInitiated) {
                PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject?.creationDate
            }.value
        }

        return VideoAsset(
            id: UUID(),
            localIdentifier: localIdentifier,
            url: url,
            filename: filename,
            duration: max(duration, 0),
            creationDate: resolvedCreationDate,
            originalSize: originalSize,
            avAsset: avAsset
        )
    }

    private func phAssetFilename(_ asset: PHAsset) -> String? {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
    }
}
