import SwiftUI
import UCITTCore

/// A reference sheet explaining every landmark, reachable from an info button on
/// both capture screens. Shows an optional overview diagram (once the asset is
/// added) plus a precise definition of each of the six points.
struct LandmarkHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private var diagram: Image? {
        UIImage(named: "LandmarksGuide").map(Image.init(uiImage:))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let diagram {
                        diagram
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Diagram of the six landmarks on a TT bike")
                    }

                    Text("Mark these six points, in order. Take your time — each one is fine-tunable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    ForEach(Array(Landmark.captureOrder.enumerated()), id: \.element) { index, landmark in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 24, height: 24)
                                .background(.tint, in: Circle())
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(landmark.title).font(.headline)
                                Text(landmark.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("What to mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
