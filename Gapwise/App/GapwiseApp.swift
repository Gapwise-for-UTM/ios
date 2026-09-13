import SwiftUI

@main
struct GapwiseApp: App {
    @State private var appModel: AppModel

    init() {
        _appModel = State(initialValue: AppDependencies.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .preferredColorScheme(appModel.preferredColorScheme)
                .task {
                    await appModel.load()
                }
        }
    }
}
