import SwiftUI
import UCITTCore

// MARK: - Brand

/// The ≫ chevron badge + "TT FIT CHECK" wordmark.
struct BrandMark: View {
    var compact = false
    var body: some View {
        HStack(spacing: 9) {
            Text("≫")
                .font(Theme.display(compact ? 15 : 17))
                .foregroundStyle(Theme.onAccent)
                .frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("TT FIT CHECK")
                .font(Theme.mono(compact ? 11 : 12, .bold))
                .tracking(3)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

/// A section header: an accent tick + an uppercase mono label.
struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(-12))
            Text(title.uppercased())
                .font(Theme.mono(11, .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Buttons

/// Primary action — accent fill, full width, 52pt.
struct SlipPrimary: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(Theme.body(15, .heavy))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
            .opacity(c.isPressed ? 0.85 : 1)
    }
}

/// Secondary action — hairline outline.
struct SlipSecondary: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(Theme.body(15, .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.line, lineWidth: 1.5))
            .opacity(c.isPressed ? 0.7 : 1)
    }
}

// MARK: - Badges & pills

/// PASS / CHECK / FAIL chip.
struct StatePill: View {
    let state: MeasurementState
    init(_ state: MeasurementState) { self.state = state }
    private var label: String {
        switch state { case .pass: return "PASS"; case .borderline: return "CHECK"; case .fail: return "FAIL" }
    }
    var body: some View {
        let c = Theme.color(for: state)
        Text(label)
            .font(Theme.mono(11, .bold))
            .foregroundStyle(c)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(c.opacity(0.13))
            .overlay(RoundedRectangle(cornerRadius: Theme.rChip).stroke(c.opacity(0.30), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.rChip))
    }
}

/// Accent-filled category badge (e.g. "CAT 1").
struct CategoryBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(10, .bold))
            .tracking(0.5)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Motion motif

/// Decorative aero speed-stripes, used in the corner of hero surfaces.
struct SpeedStripes: View {
    var color: Color = Theme.accent
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(color.opacity(0.30)).frame(width: 14)
            Rectangle().fill(color.opacity(0.16)).frame(width: 8)
        }
        .frame(height: 260)
        .rotationEffect(.degrees(18))
    }
}

// MARK: - The signature: limit gauge

/// The signature element — a value travelling toward a hard UCI limit. Shows the
/// fill (coloured by state), the limit tick, scaled so the limit sits with a
/// little headroom. Informational measurements (no limit) render nothing.
struct LimitGauge: View {
    let measurement: EvaluatedMeasurement
    var height: CGFloat = 9

    var body: some View {
        let m = measurement
        let color = Theme.color(for: m.state)
        // Limit colour: a ceiling (max) is the red wall; a floor (min) is amber.
        let markerColor = (m.direction == .max) ? Theme.fail : Theme.check
        let scaleMax = max(m.limit, m.value, 1) * 1.14
        let valueFrac = CGFloat(min(max(m.value / scaleMax, 0), 1))
        let limitFrac = CGFloat(min(max(m.limit / scaleMax, 0), 1))

        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceRaised)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(w * valueFrac, height))
                Rectangle()
                    .fill(markerColor)
                    .frame(width: 2.5, height: height + 6)
                    .position(x: w * limitFrac, y: height / 2)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Measurement card

/// One measurement: name, definition, value-vs-limit, signed margin, gauge, and
/// a state-coloured left edge. Informational rows drop the gauge + pill.
struct MeasurementCard: View {
    let measurement: EvaluatedMeasurement

    private var isInfo: Bool { measurement.limit.isNaN }
    private var isAngle: Bool { measurement.unit == "°" }

    private func fmt(_ v: Double) -> String { String(format: "%.0f", v) }
    private var valueStr: String { fmt(measurement.value) + (isAngle ? "°" : "") }
    private var limitStr: String {
        let dir = measurement.direction == .min ? " min" : ""
        return "/ \(fmt(measurement.limit))" + (isAngle ? "°" : "") + dir
    }
    private var marginStr: String {
        let s = measurement.margin >= 0 ? "+" : "−"
        return s + fmt(abs(measurement.margin)) + (isAngle ? "°" : "")
    }
    private var definition: String {
        switch measurement.kind {
        case .reach:           return "extension tip → BB · horizontal"
        case .extensionHeight: return "armrest mid → tip · vertical"
        case .armToTip:        return "armrest lead → tip · horizontal"
        case .armrestAngle:    return "armrest surface tilt"
        case .saddleSetback:   return "saddle nose → BB · selects category"
        }
    }

    var body: some View {
        let color = isInfo ? Theme.textTertiary : Theme.color(for: measurement.state)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(measurement.kind.displayName)
                        .font(Theme.body(15, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(definition)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if isInfo {
                    Text(valueStr)
                        .font(Theme.mono(19, .bold))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    StatePill(measurement.state)
                }
            }

            if !isInfo {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(valueStr)
                        .font(Theme.mono(22, .bold))
                        .foregroundStyle(measurement.state == .fail ? Theme.fail : Theme.textPrimary)
                    Text(limitStr)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text(marginStr)
                        .font(Theme.mono(12, .bold))
                        .foregroundStyle(color)
                }
                LimitGauge(measurement: measurement)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Verdict banner

/// The glanceable headline — overall pass / borderline / fail, with category.
struct VerdictBanner: View {
    let report: ResultReport

    private var state: MeasurementState { report.overallState }
    private var color: Color { Theme.color(for: state) }
    private var title: String {
        switch state {
        case .pass:       return "WITHIN LIMITS"
        case .borderline: return "BORDERLINE"
        case .fail:       return "OVER A LIMIT"
        }
    }
    private var kicker: String {
        switch state {
        case .pass:       return "◉ CHECK COMPLETE"
        case .borderline: return "⚠ RE-CHECK NEEDED"
        case .fail:       return "✕ OUTSIDE UCI LIMITS"
        }
    }
    private var note: String {
        let enforced = report.measurements.filter { !$0.limit.isNaN }
        switch state {
        case .pass:
            return "All \(enforced.count) measurements clear their UCI limits."
        case .borderline:
            let n = enforced.filter { $0.state == .borderline }.count
            return "\(n) measurement\(n == 1 ? "" : "s") within ~10 mm of a limit. Verify with tools."
        case .fail:
            let n = enforced.filter { $0.state == .fail }.count
            return "\(n) measurement\(n == 1 ? "" : "s") exceed the limit. Adjust the cockpit and re-run."
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            color.opacity(0.10)
            SpeedStripes(color: color).offset(x: 26, y: -44)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(kicker)
                        .font(Theme.mono(10, .bold))
                        .tracking(1.5)
                        .foregroundStyle(color)
                    Spacer()
                    CategoryBadge(text: report.category.displayName)
                }
                Text(title)
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(color.opacity(0.40), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Camera HUD bits

/// One corner bracket for the capture viewfinder. `corner` selects which.
struct HUDCorner: View {
    enum Corner { case tl, tr, bl, br }
    let corner: Corner
    var size: CGFloat = 26
    var body: some View {
        let topEdges: Bool = corner == .tl || corner == .tr
        let leftEdges: Bool = corner == .tl || corner == .bl
        Path { p in
            let s = size
            // horizontal arm
            let hy: CGFloat = topEdges ? 0 : s
            p.move(to: CGPoint(x: leftEdges ? 0 : s, y: hy))
            p.addLine(to: CGPoint(x: leftEdges ? s : 0, y: hy))
            // vertical arm
            let vx: CGFloat = leftEdges ? 0 : s
            p.move(to: CGPoint(x: vx, y: topEdges ? 0 : s))
            p.addLine(to: CGPoint(x: vx, y: topEdges ? s : 0))
        }
        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: size, height: size)
    }
}

/// A small status pill used over the camera (e.g. "WHEEL DETECTED", "LEVEL 0.4°").
struct StatusPill: View {
    let text: String
    var color: Color = Theme.pass
    var pulse: Bool = false
    @State private var on = true
    var body: some View {
        HStack(spacing: 6) {
            if pulse {
                Circle().fill(color).frame(width: 7, height: 7)
                    .opacity(on ? 1 : 0.35)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { on.toggle() }
                    }
            }
            Text(text)
                .font(Theme.mono(10, .bold))
                .tracking(1)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
