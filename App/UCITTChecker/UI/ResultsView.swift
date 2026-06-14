import SwiftUI
import UCITTCore

/// S5 — results: per-measurement value, limit, margin and state (§4).
struct ResultsView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        Group {
            if let report = flow.report {
                content(report)
            } else if let error = flow.checkError {
                ContentUnavailableView("Couldn't compute result",
                                       systemImage: "xmark.octagon",
                                       description: Text(message(for: error)))
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New check") { flow.reset() }
            }
        }
    }

    private func content(_ report: ResultReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headline(report)

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category: \(report.category.displayName)")
                            .font(.headline)
                        Text(report.categoryReason)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(report.measurements) { m in
                    MeasurementRow(measurement: m)
                }

                if !report.flags.isEmpty {
                    GroupBox("Notes") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(report.flags, id: \.self) { flag in
                                Label(flag, systemImage: "info.circle")
                                    .font(.footnote)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                DisclaimerBanner()

                Text("Rules version: \(report.rulesVersion)")
                    .font(.caption2).foregroundStyle(.tertiary)

                ShareLink(item: shareText(report)) {
                    Label("Share result", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func headline(_ report: ResultReport) -> some View {
        let (text, color, icon): (String, Color, String) = {
            switch report.overallState {
            case .pass:       return ("Within limits", .green, "checkmark.seal.fill")
            case .borderline: return ("Borderline — re-check", .orange, "exclamationmark.triangle.fill")
            case .fail:       return ("Over a limit", .red, "xmark.seal.fill")
            }
        }()
        return HStack {
            Image(systemName: icon).font(.title)
            Text(text).font(.title2.bold())
        }
        .foregroundStyle(color)
    }

    private func shareText(_ report: ResultReport) -> String {
        var lines = ["UCI TT Position Check (\(report.category.displayName))"]
        for m in report.measurements {
            lines.append(MeasurementRow.summaryLine(m))
        }
        lines.append("")
        lines.append(ResultReport.disclaimer)
        return lines.joined(separator: "\n")
    }

    private func message(for error: PositionChecker.Failure) -> String {
        switch error {
        case .capture: return "The capture didn't pass quality checks. Retake the photo."
        case .degenerateMarker: return "The marker corners were degenerate. Retake the photo."
        case .missingLandmarks: return "Not all landmarks were placed."
        }
    }
}

/// One measurement row with value, limit, margin and a colour-coded state.
struct MeasurementRow: View {
    let measurement: EvaluatedMeasurement

    var body: some View {
        let m = measurement
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.kind.displayName).font(.headline)
                if m.limit.isNaN {
                    Text("informational")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(m.direction == .max ? "max" : "min") \(format(m.limit)) \(m.unit) · margin \(marginString(m))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(format(m.value)) \(m.unit)")
                .font(.title3.monospacedDigit())
            stateBadge(m)
        }
        .padding(.vertical, 6)
    }

    private func stateBadge(_ m: EvaluatedMeasurement) -> some View {
        let (color, label): (Color, String) = {
            if m.limit.isNaN { return (.secondary, "—") }
            switch m.state {
            case .pass: return (.green, "PASS")
            case .borderline: return (.orange, "CHECK")
            case .fail: return (.red, "FAIL")
            }
        }()
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    static func summaryLine(_ m: EvaluatedMeasurement) -> String {
        if m.limit.isNaN {
            return "• \(m.kind.displayName): \(format(m.value)) \(m.unit)"
        }
        return "• \(m.kind.displayName): \(format(m.value)) \(m.unit) " +
               "(\(m.direction == .max ? "max" : "min") \(format(m.limit)), \(m.state.rawValue))"
    }

    private func marginString(_ m: EvaluatedMeasurement) -> String { Self.marginString(m) }
    private static func marginString(_ m: EvaluatedMeasurement) -> String {
        let sign = m.margin >= 0 ? "+" : ""
        return "\(sign)\(format(m.margin)) \(m.unit)"
    }
    private func format(_ v: Double) -> String { Self.format(v) }
    private static func format(_ v: Double) -> String { String(format: "%.0f", v) }
}
