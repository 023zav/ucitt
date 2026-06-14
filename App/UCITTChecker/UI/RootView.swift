import SwiftUI

/// Hosts the navigation stack for the guided flow (§4).
struct RootView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        NavigationStack(path: $flow.path) {
            OnboardingView()
                .navigationDestination(for: FlowStep.self) { step in
                    switch step {
                    case .onboarding: OnboardingView()
                    case .riderInput: RiderInputView()
                    case .capture:    CaptureView()
                    case .tapping:    TappingView()
                    case .arkit:      ARKitMeasureView()
                    case .results:    ResultsView()
                    }
                }
        }
    }
}
