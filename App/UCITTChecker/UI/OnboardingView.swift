import SwiftUI
import UCITTCore

/// S1 — choose a measurement mode and set up (§4).
struct OnboardingView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BrandMark().padding(.top, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check your\nUCI cockpit.")
                            .font(Theme.display(34))
                            .foregroundStyle(Theme.textPrimary)
                        Text("A ±5–10 mm pre-check before race day — not a UCI certification.")
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Measurement mode")
                        ModeCard(mode: .wheel, selected: flow.mode == .wheel, recommended: true) {
                            flow.mode = .wheel
                        }
                        ModeCard(mode: .arKit, selected: flow.mode == .arKit, recommended: false) {
                            flow.mode = .arKit
                        }
                    }

                    if let illustration {
                        illustration
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
                            .accessibilityLabel(illustrationAccessibility)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("How to set up")
                        ForEach(Array(setupSteps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", i + 1))
                                    .font(Theme.mono(12, .bold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 1)
                                Text(step)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .slipCard()
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button { flow.advance(to: .riderInput) } label: {
                HStack(spacing: 8) {
                    Text("CONTINUE").tracking(0.5)
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .heavy))
                }
            }
            .buttonStyle(SlipPrimary())

            Text("Pre-check only · re-check anything within 10 mm")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12).padding(.bottom, 10)
        .background(Theme.bg)
    }

    // MARK: Per-mode content

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

    private var setupSteps: [String] {
        switch flow.mode {
        case .wheel:
            return [
                "Pick your wheel / tyre size on the next screen — it sets the scale.",
                "Stand back and shoot the whole bike dead side-on, square to the camera.",
                "Keep both wheels fully in frame and the bike on level ground.",
                "Tap the two wheel hubs + a tyre contact point, then the 6 landmarks."
            ]
        case .arKit:
            return [
                "Use a Pro iPhone with LiDAR for best accuracy.",
                "Slowly move the phone so it builds a 3D map of the bike.",
                "Aim the on-screen reticle at each landmark and tap to capture it.",
                "Keep the bike still and well lit while you place all six points."
            ]
        }
    }
}

/// A selectable measurement-mode card.
struct ModeCard: View {
    let mode: MeasurementMode
    let selected: Bool
    var recommended: Bool = false
    let action: () -> Void

    private var title: String { mode == .wheel ? "Wheel Photo" : "LiDAR Scan" }
    private var subtitle: String {
        mode == .wheel
            ? "One side-on shot. Scale from your own wheel. Any iPhone."
            : "Markerless 3D capture. Pro models with LiDAR."
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.body(16, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if recommended {
                        Text("RECOMMENDED")
                            .font(Theme.mono(10, .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(.top, 5)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .stroke(selected ? Color.clear : Theme.line, lineWidth: 1.5)
                    if selected {
                        Circle().fill(Theme.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Theme.onAccent)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.08) : Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.accent : Theme.line, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
