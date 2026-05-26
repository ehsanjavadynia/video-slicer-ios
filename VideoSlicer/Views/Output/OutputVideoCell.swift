import SwiftUI

struct OutputVideoCell: View {

    let video: OutputVideo
    let isSelected: Bool
    let thumbnail: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                thumbnailView
                    .frame(width: AppConstants.UI.thumbnailSize.width, height: AppConstants.UI.thumbnailSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clip \(video.sliceIndex)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(video.displayDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(video.displayFileSize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.2))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clip \(video.sliceIndex), \(video.displayDuration), \(video.resolution.shortLabel), \(video.displayFileSize)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
