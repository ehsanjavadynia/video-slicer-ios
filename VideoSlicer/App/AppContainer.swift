import Foundation

@MainActor
final class AppContainer: ObservableObject {

    let galleryService: GalleryServiceProtocol
    let exportService: VideoExportServiceProtocol
    let slicerService: VideoSlicerServiceProtocol
    let thumbnailService: VideoThumbnailServiceProtocol

    let mainViewModel: MainViewModel
    let outputViewModel: OutputViewModel

    init() {
        let export = VideoExportService()
        let slicer = VideoSlicerService(exportService: export)
        let gallery = GalleryService()
        let thumbnail = VideoThumbnailService()

        self.exportService = export
        self.slicerService = slicer
        self.galleryService = gallery
        self.thumbnailService = thumbnail

        self.mainViewModel = MainViewModel(
            galleryService: gallery,
            slicerService: slicer
        )
        self.outputViewModel = OutputViewModel(thumbnailService: thumbnail)
    }
}
