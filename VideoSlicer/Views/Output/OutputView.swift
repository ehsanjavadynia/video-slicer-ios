import SwiftUI

struct OutputView: View {

    @ObservedObject var viewModel: OutputViewModel

    var body: some View {
        Group {
            if viewModel.videoGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "scissors")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Output Videos")
                        .font(.title3.weight(.semibold))
                    Text("Sliced clips will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.videoGroups) { group in
                        VideoGroupSection(
                            group: group,
                            selectedIDs: viewModel.selectedVideoIDs,
                            onToggle: { viewModel.toggleSelection(videoID: $0) },
                            onSelectAll: { viewModel.selectAll(in: $0) },
                            thumbnailProvider: { await viewModel.thumbnail(for: $0) }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Sliced Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.shareSelectedTapped()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(viewModel.selectedVideoIDs.isEmpty)
                .accessibilityLabel("Share selected clips")
            }

            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.selectedVideoIDs.isEmpty {
                    Button("Clear") {
                        viewModel.clearSelection()
                    }
                    .accessibilityLabel("Clear selection")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShareSheetPresented) {
            ShareSheet(items: viewModel.shareItems, isPresented: $viewModel.isShareSheetPresented)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
