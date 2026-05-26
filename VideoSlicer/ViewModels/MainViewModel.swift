import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class MainViewModel: ObservableObject {

    private let galleryService: GalleryServiceProtocol
    private let slicerService: VideoSlicerServiceProtocol

    @Published var selectedAsset: VideoAsset?
    @Published var sliceSettings: SliceSettings = .default
    @Published var isPickingVideo: Bool = false
    @Published var isSlicing: Bool = false
    @Published var slicingProgress: Double = 0.0
    @Published var slicingProgressText: String = ""
    @Published var outputVideos: [OutputVideo] = []
    @Published var errorMessage: String?
    @Published var navigateToOutput: Bool = false

    var canStartSlicing: Bool {
        selectedAsset != nil && !isSlicing && sliceSettings.isValid
    }

    var estimatedSegmentCount: Int {
        guard let asset = selectedAsset, sliceSettings.maxSliceDuration > 0 else { return 0 }
        return Int(ceil(asset.duration / sliceSettings.maxSliceDuration))
    }

    init(galleryService: GalleryServiceProtocol, slicerService: VideoSlicerServiceProtocol) {
        self.galleryService = galleryService
        self.slicerService = slicerService
        loadUITestAssetIfNeeded()
    }

    func pickVideoTapped(presentingViewController: UIViewController) async {
        isPickingVideo = true
        defer { isPickingVideo = false }
        do {
            let asset = try await galleryService.pickVideo(presentingViewController: presentingViewController)
            selectedAsset = asset
        } catch GalleryError.cancelled {
            // user cancelled — no error shown
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSlicingTapped() async {
        guard let asset = selectedAsset, canStartSlicing else { return }

        isSlicing = true
        slicingProgress = 0
        slicingProgressText = ""
        outputVideos = []

        defer {
            isSlicing = false
            slicingProgressText = ""
        }

        do {
            let stream = try await slicerService.slice(asset: asset, settings: sliceSettings)
            for await progress in stream {
                slicingProgress = progress.fraction
                slicingProgressText = "Exporting \(progress.completedSegments) of \(progress.totalSegments)..."
                if let output = progress.latestOutput {
                    outputVideos.append(output)
                }
                if progress.isComplete {
                    navigateToOutput = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelSlicing() {
        guard let asset = selectedAsset else { return }
        slicerService.cancel(assetID: asset.id)
        isSlicing = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func loadUITestAssetIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: AppConstants.UITest.videoURLArgumentKey),
              idx + 1 < args.count else { return }
        let urlString = args[idx + 1]
        let url = URL(fileURLWithPath: urlString)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let avAsset = AVURLAsset(url: url)  // swiftlint:disable:this identifier_name
        let duration = CMTimeGetSeconds(avAsset.duration)
        selectedAsset = VideoAsset(
            id: UUID(),
            localIdentifier: url.lastPathComponent,
            url: url,
            filename: url.lastPathComponent,
            duration: max(duration, 0),
            creationDate: nil,
            originalSize: .zero
        )
    }
}
