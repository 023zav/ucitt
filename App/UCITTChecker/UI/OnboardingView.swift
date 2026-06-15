import SwiftUI
import UCITTCore

/// S1 — choose a measurement mode and set up (§4).
struct OnboardingView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("UCI TT Position Checker")
                    .font(.title.bold())

                Text("A quick pre-check for your TT cockpit. Not a UCI certification.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GroupBox("Measurement mode") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Mode", selection: $flow.mode) {
                            ForEach(MeasurementMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(modeBlurb)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("How to set up") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let illustration {
                            illustration
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 150)
                                .accessibilityLabel(illustrationAccessibility)
                        }
                        ForEach(setupSteps, id: \.text) { step in
                            Label(step.text, systemImage: step.icon)
                        }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclaimerBanner()
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                flow.advance(to: .riderInput)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeBlurb: String {
        switch flow.mode {
        case .wheel:
            return "Take one square-on side-on photo of the whole bike. Scale comes from your wheel — no object to attach. Works on any iPhone."
        case .arKit:
            return "Point the phone at the bike and tap each landmark in 3D. Best on Pro models with LiDAR. No reference object."
        }
    }

    /// The per-mode diagram, shown only once its asset has been added.
    private var illustrationName: String {
        flow.mode == .wheel ? "WheelPlacement" : "ARKitScan"
    }

    private var illustration: Image? {
        UIImage(named: illustrationName).map(Image.init(uiImage:))
    }

    private var illustrationAccessibility: String {
        flow.mode == .wheel
            ? "How to frame the bike for a wheel-scaled photo"
            : "Aiming the phone at the bike to capture landmarks"
    }

    private struct Step { let text: String; let icon: String }

    private var setupSteps: [Step] {
        switch flow.mode {
        case .wheel:
            return [
                Step(text: "Pick your wheel/tyre size on the next screen — it sets the scale.",
                     icon: "bicycle"),
                Step(text: "Stand back and shoot the whole bike dead side-on, square to the camera.",
                     icon: "camera"),
                Step(text: "Keep both wheels fully in frame and the bike on level ground.",
                     icon: "ruler"),
                Step(text: "You'll then tap the two wheel hubs + a tyre contact point, and the 6 landmarks.",
                     icon: "hand.tap")
            ]
        case .arKit:
            return [
                Step(text: "Use a Pro iPhone with LiDAR for best accuracy.",
                     icon: "cube.transparent"),
                Step(text: "Slowly move the phone so it builds a 3D map of the bike.",
                     icon: "arkit"),
                Step(text: "Aim the on-screen reticle at each landmark and tap to capture it.",
                     icon: "scope"),
                Step(text: "Keep the bike still and well lit while you place all six points.",
                     icon: "light.max")
            ]
        }
    }
}
