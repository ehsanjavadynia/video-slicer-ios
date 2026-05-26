import Foundation
import UIKit

@MainActor
final class OutputViewModel: ObservableObject {

    private let thumbnailService: VideoThumbnailServiceProtocol

    @Published var videoGroups: [VideoGroup] = []
    @Published var selectedVideoIDs: Set<UUID> = []
    @Published var isShareSheetPresented: Bool = false
    @Published var shareItems: [Any] = []
    @Published var errorMessage: String?

    init(thumbnailService: VideoThumbnailServiceProtocol) {
        self.thumbnailService = thumbnailService
    }

    func loadOutputVideos(_ videos: [OutputVideo]) {
        let grouped = Dictionary(grouping: videos, by: \.sourceAssetID)
        videoGroups = grouped
            .map { assetID, groupVideos -> VideoGroup in
                let sorted = groupVideos.sorted { $0.sliceIndex < $1.sliceIndex }
                return VideoGroup(
                    id: assetID,
                    sourceFilename: sorted.first?.sourceFilename ?? "",
                    videos: sorted
                )
            }
            .sorted { ($0.videos.first?.createdAt ?? .distantPast) < ($1.videos.first?.createdAt ?? .distantPast) }
    }

    func toggleSelection(videoID: UUID) {
        if selectedVideoIDs.contains(videoID) {
            selectedVideoIDs.remove(videoID)
        } else {
            selectedVideoIDs.insert(videoID)
        }
    }

    func selectAll(in groupID: UUID) {
        guard let group = videoGroups.first(where: { $0.id == groupID }) else { return }
        group.videos.forEach { selectedVideoIDs.insert($0.id) }
    }

    func clearSelection() {
        selectedVideoIDs.removeAll()
    }

    func shareSelectedTapped() {
        let urls = videoGroups
            .flatMap(\.videos)
            .filter { selectedVideoIDs.contains($0.id) }
            .map(\.url)
        shareItems = urls
        isShareSheetPresented = true
    }

    func thumbnail(for outputVideo: OutputVideo) async -> UIImage? {
        try? await thumbnailService.thumbnail(
            for: outputVideo.url,
            at: .zero,
            size: AppConstants.UI.thumbnailSize
        )
    }

    func clearError() {
        errorMessage = nil
    }
}

