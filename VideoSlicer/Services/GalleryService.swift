import AVFoundation
import Photos
import PhotosUI
import UIKit

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

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            pickerContinuation?.resume(throwing: GalleryError.cancelled)
            pickerContinuation = nil
            return
        }

        guard result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") else {
            pickerContinuation?.resume(throwing: GalleryError.unsupportedFormat)
            pickerContinuation = nil
            return
        }

        let assetIdentifier = result.assetIdentifier
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
            guard let self else { return }
            if let error {
                self.pickerContinuation?.resume(throwing: GalleryError.exportFailed(error.localizedDescription))
                self.pickerContinuation = nil
                return
            }
            guard let url else {
                self.pickerContinuation?.resume(throwing: GalleryError.exportFailed("No URL returned"))
                self.pickerContinuation = nil
                return
            }
            do {
                let stagedURL = try self.stageInputFile(from: url)
                let asset = self.buildVideoAsset(stagedURL: stagedURL, assetIdentifier: assetIdentifier)
                self.pickerContinuation?.resume(returning: asset)
            } catch {
                self.pickerContinuation?.resume(throwing: error)
            }
            self.pickerContinuation = nil
        }
    }

    private func stageInputFile(from url: URL) throws -> URL {
        let stagingDir = AppConstants.Paths.inputStagingDirectory
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let destination = stagingDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private func buildVideoAsset(stagedURL: URL, assetIdentifier: String?) -> VideoAsset {
        let avAsset = AVURLAsset(url: stagedURL)
        let duration = CMTimeGetSeconds(avAsset.duration)

        var originalSize = CGSize.zero
        if let track = avAsset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            originalSize = CGSize(width: abs(size.width), height: abs(size.height))
        }

        var creationDate: Date?
        if let identifier = assetIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            creationDate = fetchResult.firstObject?.creationDate
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
