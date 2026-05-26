import SwiftUI

struct VideoGroupSection: View {

    let group: VideoGroup
    let selectedIDs: Set<UUID>
    let onToggle: (UUID) -> Void
    let onSelectAll: (UUID) -> Void
    @State private var thumbnails: [UUID: UIImage] = [:]

    var thumbnailProvider: (OutputVideo) async -> UIImage?

    var body: some View {
        Section {
            ForEach(group.videos) { video in
                OutputVideoCell(
                    video: video,
                    isSelected: selectedIDs.contains(video.id),
                    thumbnail: thumbnails[video.id],
                    onTap: { onToggle(video.id) }
                )
                .task(id: video.id) {
                    if let image = await thumbnailProvider(video) {
                        thumbnails[video.id] = image
                    }
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displaySourceName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(group.displayCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select All") { onSelectAll(group.id) }
                    .font(.caption)
                    .accessibilityLabel("Select all clips from \(group.displaySourceName)")
            }
            .textCase(nil)
        }
    }
}
