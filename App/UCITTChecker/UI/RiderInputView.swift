import SwiftUI

/// S2 — rider inputs (§4).
struct RiderInputView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        Form {
            Section("Rider") {
                Stepper(value: $flow.heightCm, in: 140...210, step: 0.5) {
                    LabeledContent("Height", value: "\(flow.heightCm, specifier: "%.1f") cm")
                }
            }

            Section("Saddle setback") {
                Toggle("Enter setback manually", isOn: $flow.useSetbackOverride)
                if flow.useSetbackOverride {
                    Stepper(value: $flow.setbackOverrideMm, in: 0...150, step: 1) {
                        LabeledContent("Setback", value: "\(Int(flow.setbackOverrideMm)) mm")
                    }
                    Text("Use this if the saddle nose won't be cleanly visible in the photo.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Setback will be measured from your tap on the saddle nose.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Marker size") {
                Stepper(value: $flow.markerWidthMM, in: 50...300, step: 5) {
                    LabeledContent("Width", value: "\(Int(flow.markerWidthMM)) mm")
                }
                Stepper(value: $flow.markerHeightMM, in: 50...300, step: 5) {
                    LabeledContent("Height", value: "\(Int(flow.markerHeightMM)) mm")
                }
                Text("Confirm this matches the printed marker exactly — it sets the scale.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rider")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Capture") { flow.advance(to: .capture) }
            }
        }
    }
}
