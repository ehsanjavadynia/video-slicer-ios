import SwiftUI

struct SliceActionButton: View {

    let isSlicing: Bool
    let progress: Double
    let progressText: String
    let canStart: Bool
    let onTap: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isSlicing {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                    HStack {
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityHint("Stops the current slicing operation")
                    }
                }
            }

            Button(action: isSlicing ? {} : onTap) {
                HStack(spacing: 10) {
                    if isSlicing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "scissors")
                    }
                    Text(isSlicing ? "Slicing..." : "Slice Video")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canStart && !isSlicing ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                )
                .foregroundStyle(canStart && !isSlicing ? .white : .secondary)
            }
            .disabled(!canStart || isSlicing)
            .accessibilityLabel(isSlicing ? "Slicing video" : "Slice video")
            .accessibilityHint(canStart ? "Double tap to start slicing" : "Select a video first")
        }
    }
}
