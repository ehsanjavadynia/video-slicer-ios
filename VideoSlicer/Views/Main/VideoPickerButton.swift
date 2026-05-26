import SwiftUI

struct VideoPickerButton: View {

    let asset: VideoAsset?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: asset == nil ? "photo.on.rectangle" : "video.fill")
                    .font(.title2)
                    .foregroundStyle(asset == nil ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset == nil ? "Choose Video" : asset!.filename)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let asset {
                        Text(asset.displayDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Select a video from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset == nil ? "Choose video" : "Selected video: \(asset!.filename)")
    }
}
