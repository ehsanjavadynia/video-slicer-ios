// UIKit is imported here as an accepted exception: `pickVideoTapped` must accept
// UIViewController to present PHPickerViewController via the GalleryServiceProtocol.
// Removing UIViewController from the API would require a large protocol refactor.
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
        selectedAsset != nil && (selectedAsset?.duration ?? 0) > 0 && !isSlicing && sliceSettings.isValid
    }

    var estimatedSegmentCount: Int {
        guard let asset = selectedAsset, sliceSettings.maxSliceDuration > 0 else { return 0 }
        return Int(ceil(asset.duration / sliceSettings.maxSliceDuration))
    }

    init(galleryService: GalleryServiceProtocol, slicerService: VideoSlicerServiceProtocol) {
        self.galleryService = galleryService
        self.slicerService = slicerService
        loadUITestAssetIfNeeded()
        loadUITestOutputIfNeeded()
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

        navigateToOutput = false
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
            for try await progress in stream {
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
        slicingProgress = 0
        slicingProgressText = ""
        outputVideos = []
    }

    func deleteOutputVideos() {
        let urls = outputVideos.map(\.url)
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        outputVideos = []
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
        // AVFoundation logic is encapsulated in VideoAsset.fromURL(_:) in the Models layer
        selectedAsset = VideoAsset.fromURL(url)
    }

    private func loadUITestOutputIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: AppConstants.UITest.outputVideoURLArgumentKey),
              idx + 1 < args.count else { return }
        let url = URL(fileURLWithPath: args[idx + 1])
        let sourceAssetID = UUID()
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        outputVideos = [
            OutputVideo(
                id: UUID(),
                sourceAssetID: sourceAssetID,
                sourceFilename: url.lastPathComponent,
                url: url,
                sliceIndex: 1,
                duration: 5,
                resolution: .p720,
                quality: .medium,
                fileSize: fileSize,
                createdAt: Date()
            )
        ]
    }
}
