import SwiftUI
import UCITTCore

/// S5 — results: per-measurement value, limit, margin and state (§4).
struct ResultsView: View {
    @EnvironmentObject private var flow: CheckFlowModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Group {
                if let report = flow.report {
                    content(report)
                } else if let error = flow.checkError {
                    ContentUnavailableView("Couldn't compute result",
                                           systemImage: "xmark.octagon",
                                           description: Text(message(for: error)))
                } else {
                    ProgressView().tint(Theme.accent)
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New check") { flow.reset() }
                    .font(Theme.body(14, .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func content(_ report: ResultReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VerdictBanner(report: report)

                // Category + why
                HStack(alignment: .top, spacing: 12) {
                    CategoryBadge(text: report.category.displayName)
                    Text(report.categoryReason)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .slipCard(padding: 14)

                ForEach(report.measurements) { m in
                    MeasurementCard(measurement: m)
                }

                if !report.flags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Notes")
                        ForEach(report.flags, id: \.self) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                                Text(flag)
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .slipCard()
                }

                DisclaimerBanner()

                Text("Rules version: \(report.rulesVersion)")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary)

                debugSection
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) { shareBar(report) }
    }

    private func shareBar(_ report: ResultReport) -> some View {
        ShareLink(item: shareText(report)) {
            HStack(spacing: 8) {
                Text("SHARE REPORT").font(Theme.body(15, .heavy))
                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12).padding(.bottom, 10)
        .background(Theme.bg)
    }

    @ViewBuilder
    private var debugSection: some View {
        if !flow.lastDebugText.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text(flow.lastDebugText)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        ShareLink(item: flow.lastDebugText) {
                            Label("This run", systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                        ShareLink(item: RunLog.wholeLogText()) {
                            Label("Full log", systemImage: "doc.text")
                        }
                    }
                    .font(Theme.body(12))
                    .tint(Theme.accent)
                }
                .padding(.top, 6)
            } label: {
                Text("Debug data")
                    .font(Theme.body(13, .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .tint(Theme.textSecondary)
            .padding(14)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        }
    }

    private func shareText(_ report: ResultReport) -> String {
        var lines = ["TT Fit Check — UCI TT Position (\(report.category.displayName))"]
        for m in report.measurements {
            lines.append(summaryLine(m))
        }
        lines.append("")
        lines.append(ResultReport.disclaimer)
        return lines.joined(separator: "\n")
    }

    private func summaryLine(_ m: EvaluatedMeasurement) -> String {
        func f(_ v: Double) -> String { String(format: "%.0f", v) }
        if m.limit.isNaN {
            return "• \(m.kind.displayName): \(f(m.value)) \(m.unit)"
        }
        return "• \(m.kind.displayName): \(f(m.value)) \(m.unit) " +
               "(\(m.direction == .max ? "max" : "min") \(f(m.limit)), \(m.state.rawValue))"
    }

    private func message(for error: PositionChecker.Failure) -> String {
        switch error {
        case .capture: return "The capture didn't pass quality checks. Retake the photo."
        case .degenerateMarker: return "The marker corners were degenerate. Retake the photo."
        case .missingLandmarks: return "Not all landmarks were placed."
        }
    }
}
