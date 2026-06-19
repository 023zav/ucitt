import SwiftUI
import UCITTCore

/// S2 — rider inputs.
struct RiderInputView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    private var categoryPreview: String {
        let setback = flow.useSetbackOverride ? flow.setbackOverrideMm : 60
        return CategoryEngine.decide(heightCm: flow.heightCm, saddleSetbackMm: setback)
            .category.displayName
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Height
                    SectionHeader("Rider height")
                    VStack(spacing: 14) {
                        HStack {
                            stepButton("minus") { flow.heightCm = max(140, flow.heightCm - 0.5) }
                            Spacer()
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text("\(Int(flow.heightCm))")
                                        .font(Theme.mono(40, .bold))
                                        .foregroundStyle(Theme.accent)
                                    Text(String(format: ".%01d", Int((flow.heightCm * 10).rounded()) % 10))
                                        .font(Theme.mono(18, .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                Text("CM")
                                    .font(Theme.mono(11, .semibold))
                                    .tracking(1)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            stepButton("plus", accent: true) { flow.heightCm = min(210, flow.heightCm + 0.5) }
                        }
                        TapeRuler(fraction: (flow.heightCm - 140) / 70)
                    }
                    .slipCard()

                    // Saddle setback
                    SectionHeader("Saddle setback")
                    VStack(spacing: 0) {
                        Toggle(isOn: $flow.useSetbackOverride) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enter setback manually")
                                    .font(Theme.body(14, .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(flow.useSetbackOverride
                                     ? "Using your entered value."
                                     : "Measured from your saddle-nose tap.")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accent)

                        if flow.useSetbackOverride {
                            Divider().overlay(Theme.line).padding(.vertical, 12)
                            HStack {
                                stepButton("minus") { flow.setbackOverrideMm = max(0, flow.setbackOverrideMm - 1) }
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(flow.setbackOverrideMm))")
                                        .font(Theme.mono(28, .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("mm").font(Theme.mono(13)).foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                stepButton("plus", accent: true) { flow.setbackOverrideMm = min(150, flow.setbackOverrideMm + 1) }
                            }
                        }
                    }
                    .slipCard()

                    // Wheel size (wheel mode only)
                    if flow.mode == .wheel {
                        SectionHeader("Wheel / tyre size")
                        FlowChips(items: WheelSize.allCases, selection: $flow.wheelSize) { $0.displayName }
                        Text("Read the tyre sidewall (e.g. 700×25c). This sets the photo scale.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Rider")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bottomBar: some View {
        Button { flow.advance(to: flow.captureStep) } label: {
            HStack {
                Text(flow.mode == .arKit ? "SCAN" : "CAPTURE")
                    .font(Theme.body(15, .heavy))
                Spacer()
                Text("→ \(categoryPreview.uppercased())")
                    .font(Theme.mono(11, .bold))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 12).padding(.bottom, 10)
        .background(Theme.bg)
    }

    private func stepButton(_ symbol: String, accent: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent ? Theme.onAccent : Theme.textPrimary)
                .frame(width: 46, height: 46)
                .background(accent ? Theme.accent : Theme.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent ? Color.clear : Theme.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

/// A decorative tape-ruler that highlights the current position.
struct TapeRuler: View {
    let fraction: Double
    var body: some View {
        let count = 21
        let active = Int((Double(count - 1) * min(max(fraction, 0), 1)).rounded())
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Theme.accent : Theme.surfaceRaised)
                    .frame(maxWidth: .infinity)
                    .frame(height: (i % 5 == 0 || i == active) ? 22 : 12)
            }
        }
        .frame(height: 22)
    }
}

/// A wrapping row of selectable pills bound to a value.
struct FlowChips<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        // Simple wrapping via a lazy grid of adaptive chips.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                let on = item == selection
                Button { selection = item } label: {
                    Text(label(item))
                        .font(Theme.body(12, .semibold))
                        .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(on ? Theme.accent : Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? Color.clear : Theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
