import SwiftUI

@main
struct UCITTCheckerApp: App {
    @StateObject private var flow = CheckFlowModel()

    init() {
        Theme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(flow)
                .tint(Theme.accent)
        }
    }
}
