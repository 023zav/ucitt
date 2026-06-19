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
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let diagram {
                            diagram
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
                                .accessibilityLabel("Diagram of the six landmarks on a TT bike")
                        }

                        Text("Mark these six points, in order. Take your time — each one is fine-tunable.")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(Array(Landmark.captureOrder.enumerated()), id: \.element) { index, landmark in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", index + 1))
                                    .font(Theme.mono(13, .bold))
                                    .foregroundStyle(Theme.onAccent)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(landmark.title)
                                        .font(Theme.body(15, .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(landmark.detail)
                                        .font(Theme.body(13))
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .slipCard(padding: 14)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("What to mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.body(15, .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
