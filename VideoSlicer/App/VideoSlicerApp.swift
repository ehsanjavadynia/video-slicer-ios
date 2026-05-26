import SwiftUI

@main
struct VideoSlicerApp: App {

    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: container.mainViewModel, outputViewModel: container.outputViewModel)
        }
    }
}
