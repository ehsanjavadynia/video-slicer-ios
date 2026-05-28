import SwiftUI
import UIKit

struct MainView: View {

    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var outputViewModel: OutputViewModel
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.UI.sectionSpacing) {
                    headerSection
                    videoPickerSection
                    settingsSection
                    Spacer(minLength: 8)
                    actionSection
                }
                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("VideoSlicer")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $viewModel.navigateToOutput) {
                OutputView(viewModel: outputViewModel, onDeleteAll: deleteConvertedVideos)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.navigateToOutput = true
                        } label: {
                            Label("Converted Videos", systemImage: "film.stack")
                        }

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Converted Videos", systemImage: "trash")
                        }
                        .disabled(viewModel.outputVideos.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Navigation menu")
                }
            }
            .confirmationDialog(
                "Delete all converted videos?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Videos", role: .destructive) {
                    deleteConvertedVideos()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes the converted clips from this app.")
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
        .overlay {
            if viewModel.isPickingVideo {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    pickingProgressIndicator
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: AppConstants.UI.animationDuration), value: viewModel.isPickingVideo)
    }

    @ViewBuilder
    private var pickingProgressIndicator: some View {
        // Determinate bar when PHImageManager reports iCloud download progress,
        // otherwise an indeterminate spinner for the file-copy / metadata-load phase.
        if viewModel.pickingProgress > 0 && viewModel.pickingProgress < 1 {
            VStack(spacing: 8) {
                ProgressView(value: viewModel.pickingProgress)
                    .frame(width: 220)
                Text("Downloading from iCloud \(Int(viewModel.pickingProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ProgressView("Loading video...")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Slice a video into shorter clips.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var videoPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Video")
            VideoPickerButton(asset: viewModel.selectedAsset) {
                presentVideoPicker()
            }
            .disabled(viewModel.isPickingVideo)
        }
    }

    private func presentVideoPicker() {
        // PHPickerViewController is its own modal — present it on the topmost
        // view controller rather than wrapping it in a SwiftUI sheet. Wrapping
        // in a sheet left a blank sheet on screen while the picked file was
        // copied and AVAsset metadata loaded, which looked like a hang.
        guard let topVC = MainView.topViewController() else { return }
        Task { @MainActor [weak viewModel] in
            await viewModel?.pickVideoTapped(presentingViewController: topVC)
        }
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.sectionSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Settings")
                SliceDurationPicker(
                    duration: $viewModel.sliceSettings.maxSliceDuration,
                    estimatedSegments: viewModel.estimatedSegmentCount
                )
            }

            ResolutionPicker(resolution: $viewModel.sliceSettings.resolution)
            QualityPicker(quality: $viewModel.sliceSettings.quality)
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
    }

    private var actionSection: some View {
        SliceActionButton(
            isSlicing: viewModel.isSlicing,
            progress: viewModel.slicingProgress,
            progressText: viewModel.slicingProgressText,
            canStart: viewModel.canStartSlicing,
            onTap: { Task { [weak viewModel] in await viewModel?.startSlicingTapped() } },
            onCancel: { viewModel.cancelSlicing() }
        )
    }

    private func deleteConvertedVideos() {
        viewModel.deleteOutputVideos()
        outputViewModel.clearOutputVideos()
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

