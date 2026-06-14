import SwiftUI
import UCITTCore

/// S1 — choose a measurement mode and set up (§4).
struct OnboardingView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("UCI TT Position Checker")
                    .font(.largeTitle.bold())

                Text("A quick pre-check for your time-trial cockpit. Not a UCI certification.")
                    .foregroundStyle(.secondary)

                GroupBox("Measurement mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Mode", selection: $flow.mode) {
                            ForEach(MeasurementMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(modeBlurb)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("How to set up") {
                    VStack(alignment: .leading, spacing: 12) {
                        if flow.mode == .bankCardPhoto, illustration != nil {
                            illustration!
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Where to place the bank card on the bike")
                        }
                        ForEach(setupSteps, id: \.text) { step in
                            Label(step.text, systemImage: step.icon)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                DisclaimerBanner()

                Button {
                    flow.advance(to: .riderInput)
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeBlurb: String {
        switch flow.mode {
        case .bankCardPhoto:
            return "Take one side-on photo with any bank card in frame for scale. Works on any iPhone. No printing."
        case .arKit:
            return "Point the phone at the bike and tap each landmark in 3D. Best on Pro models with LiDAR. No reference object."
        }
    }

    /// The placement diagram, shown only once the asset has been added.
    private var illustration: Image? {
        UIImage(named: "CardPlacement").map(Image.init(uiImage:))
    }

    private struct Step { let text: String; let icon: String }

    private var setupSteps: [Step] {
        switch flow.mode {
        case .bankCardPhoto:
            return [
                Step(text: "Grab any bank/credit/ID card — they're all exactly 85.6 × 54 mm.",
                     icon: "creditcard"),
                Step(text: "Hold or tape it in the cockpit plane (same vertical plane as the extensions), long edge horizontal.",
                     icon: "bicycle"),
                Step(text: "Keep it level — captures tilted more than ~1° are rejected.",
                     icon: "level"),
                Step(text: "Get the bike fully side-on, with the card sharp and fully in frame.",
                     icon: "camera")
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
