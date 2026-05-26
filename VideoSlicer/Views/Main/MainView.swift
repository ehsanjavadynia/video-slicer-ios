import SwiftUI
import UIKit

struct MainView: View {

    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var outputViewModel: OutputViewModel
    @State private var showingPicker = false

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
                OutputView(viewModel: outputViewModel)
            }
            .onChange(of: viewModel.navigateToOutput) { navigating in
                if navigating {
                    outputViewModel.loadOutputVideos(viewModel.outputVideos)
                }
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
        .sheet(isPresented: $showingPicker) {
            VideoPicker { viewController in
                Task { [weak viewModel] in await viewModel?.pickVideoTapped(presentingViewController: viewController) }
                showingPicker = false
            }
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
                showingPicker = true
            }
        }
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

private struct VideoPicker: UIViewControllerRepresentable {
    let onPresent: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if uiViewController.presentedViewController == nil {
            DispatchQueue.main.async {
                onPresent(uiViewController)
            }
        }
    }
}
