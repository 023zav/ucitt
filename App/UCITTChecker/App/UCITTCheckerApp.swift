import SwiftUI

@main
struct UCITTCheckerApp: App {
    @StateObject private var flow = CheckFlowModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(flow)
        }
    }
}
