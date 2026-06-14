import Foundation

/// Turns a set of raw measurements into a full `ResultReport` by running the
/// category logic and the evaluator. Shared by every measurement mode (bank-card
/// photo and ARKit), so the rules pipeline lives in exactly one place.
public enum ReportBuilder {

    public static func build(rawMeasurements: [Measurement],
                             heightCm: Double,
                             setbackOverrideMm: Double?,
                             rules: UCIRules = .current) -> ResultReport {

        // Setback used for categorisation: override wins if supplied.
        let measuredSetback = rawMeasurements
            .first(where: { $0.kind == .saddleSetback })?.value ?? 0
        let setbackForCategory = setbackOverrideMm ?? measuredSetback

        let decision = CategoryEngine.decide(heightCm: heightCm,
                                             saddleSetbackMm: setbackForCategory,
                                             rules: rules)

        // If overridden, reflect the override in the reported measurement too.
        let measurements: [Measurement]
        if let override = setbackOverrideMm {
            measurements = rawMeasurements.map {
                $0.kind == .saddleSetback ? Measurement(kind: .saddleSetback, value: override) : $0
            }
        } else {
            measurements = rawMeasurements
        }

        let evaluated = Evaluator.evaluate(measurements: measurements,
                                           category: decision.category,
                                           rules: rules)

        return ResultReport(rulesVersion: rules.rulesVersion,
                            heightCm: heightCm,
                            category: decision.category,
                            categoryReason: decision.reason,
                            flags: decision.flags,
                            measurements: evaluated)
    }
}
