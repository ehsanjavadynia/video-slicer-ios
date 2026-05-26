import SwiftUI

struct QualityPicker: View {

    @Binding var quality: VideoQuality

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Quality")
                .font(.subheadline.weight(.semibold))

            Picker("Quality", selection: $quality) {
                ForEach(VideoQuality.allCases) { q in
                    Text(q.displayLabel).tag(q)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Output quality")
        }
    }
}
