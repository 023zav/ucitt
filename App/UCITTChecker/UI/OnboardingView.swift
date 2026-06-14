import SwiftUI
import UCITTCore

/// S1 — marker setup instructions (§4).
struct OnboardingView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("UCI TT Position Checker")
                    .font(.largeTitle.bold())

                Text("A quick pre-check for your time-trial cockpit. Not a UCI certification.")
                    .foregroundStyle(.secondary)

                GroupBox("Set up the marker") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Print the marker at its exact size (\(Int(flow.markerWidthMM)) × \(Int(flow.markerHeightMM)) mm) and tape it to a rigid board.",
                              systemImage: "printer")
                        Label("Stand the board next to the bike, in line with the extensions (same vertical plane as the cockpit centerline).",
                              systemImage: "bicycle")
                        Label("Make it level — one marker axis must be plumb. The app rejects captures tilted more than ~1°.",
                              systemImage: "level")
                        Label("Get the bike fully side-on, with the marker sharp and fully in frame.",
                              systemImage: "camera")
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                DisclaimerBanner()

                Button {
                    flow.advance(to: .riderInput)
                } label: {
                    Text("I've placed the marker")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
