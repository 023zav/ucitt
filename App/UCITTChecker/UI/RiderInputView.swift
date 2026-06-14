import SwiftUI

/// S2 — rider inputs (§4).
struct RiderInputView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        Form {
            Section("Rider") {
                Stepper(value: $flow.heightCm, in: 140...210, step: 0.5) {
                    LabeledContent("Height", value: String(format: "%.1f cm", flow.heightCm))
                }
            }

            Section("Saddle setback") {
                Toggle("Enter setback manually", isOn: $flow.useSetbackOverride)
                if flow.useSetbackOverride {
                    Stepper(value: $flow.setbackOverrideMm, in: 0...150, step: 1) {
                        LabeledContent("Setback", value: "\(Int(flow.setbackOverrideMm)) mm")
                    }
                    Text("Use this if the saddle nose won't be cleanly visible.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Setback will be measured from your saddle-nose landmark.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Mode") {
                LabeledContent("Measuring with", value: flow.mode.displayName)
            }
        }
        .navigationTitle("Rider")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(flow.mode == .arKit ? "Scan" : "Capture") {
                    flow.advance(to: flow.captureStep)
                }
            }
        }
    }
}
