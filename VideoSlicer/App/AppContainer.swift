import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {

    let galleryService: GalleryServiceProtocol
    let exportService: VideoExportServiceProtocol
    let slicerService: VideoSlicerServiceProtocol
    let thumbnailService: VideoThumbnailServiceProtocol

    let mainViewModel: MainViewModel
    let outputViewModel: OutputViewModel

    private var cancellables = Set<AnyCancellable>()

    init() {
        let export = VideoExportService()
        let slicer = VideoSlicerService(exportService: export)
        let gallery = GalleryService()
        let thumbnail = VideoThumbnailService()

        self.exportService = export
        self.slicerService = slicer
        self.galleryService = gallery
        self.thumbnailService = thumbnail

        let mainVM = MainViewModel(
            galleryService: gallery,
            slicerService: slicer
        )
        let outputVM = OutputViewModel(thumbnailService: thumbnail)

        self.mainViewModel = mainVM
        self.outputViewModel = outputVM

        // Drive OutputViewModel from MainViewModel so Views don't need to orchestrate ViewModels
        mainVM.$outputVideos
            .combineLatest(mainVM.$navigateToOutput)
            .filter { _, navigating in navigating }
            .map { videos, _ in videos }
            .sink { [weak outputVM] videos in
                outputVM?.loadOutputVideos(videos)
            }
            .store(in: &cancellables)
    }
}
