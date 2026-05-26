import SwiftUI

struct ResolutionPicker: View {

    @Binding var resolution: VideoResolution

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Resolution")
                .font(.subheadline.weight(.semibold))

            Picker("Resolution", selection: $resolution) {
                ForEach(VideoResolution.allCases) { res in
                    Text(res.shortLabel).tag(res)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Output resolution")
        }
    }
}
