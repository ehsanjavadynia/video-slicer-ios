import SwiftUI

struct SliceDurationPicker: View {

    @Binding var duration: TimeInterval
    let estimatedSegments: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Segment Duration")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AppConstants.Slicing.durationPresets, id: \.self) { preset in
                        DurationChip(
                            label: label(for: preset),
                            isSelected: duration == preset,
                            onTap: { duration = preset }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }

            if estimatedSegments > 0 {
                Text("~\(estimatedSegments) clip\(estimatedSegments == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var formattedDuration: String {
        label(for: duration)
    }

    private func label(for seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        guard secs >= 60 else { return "\(secs)s" }

        let minutes = secs / 60
        let remainingSeconds = secs % 60
        if remainingSeconds == 0 { return "\(minutes)m" }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct DurationChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.6)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) per segment")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
