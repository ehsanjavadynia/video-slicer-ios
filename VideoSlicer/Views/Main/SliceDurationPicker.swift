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

            HStack(spacing: 0) {
                wheel(selection: minutesBinding, range: 0...Self.maxMinutes, unit: "min")
                wheel(selection: secondsBinding, range: 0...59, unit: "sec")
            }
            .frame(height: 140)

            if estimatedSegments > 0 {
                Text("~\(estimatedSegments) clip\(estimatedSegments == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static let maxMinutes: Int = Int(AppConstants.Slicing.maximumSliceDuration) / 60

    private var totalSeconds: Int { Int(duration) }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { totalSeconds / 60 },
            set: { newMinutes in
                let secs = totalSeconds % 60
                duration = clamp(TimeInterval(newMinutes * 60 + secs))
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { totalSeconds % 60 },
            set: { newSeconds in
                let mins = totalSeconds / 60
                duration = clamp(TimeInterval(mins * 60 + newSeconds))
            }
        )
    }

    private func clamp(_ value: TimeInterval) -> TimeInterval {
        let range = AppConstants.Slicing.durationRange
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private func wheel(selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 4) {
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(unit)")
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedDuration: String {
        let secs = totalSeconds
        let minutes = secs / 60
        let remainingSeconds = secs % 60
        if minutes == 0 { return "\(remainingSeconds)s" }
        if remainingSeconds == 0 { return "\(minutes)m" }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
