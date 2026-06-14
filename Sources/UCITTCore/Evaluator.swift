import Foundation

/// Pass/fail state of a single measurement against its limit.
public enum MeasurementState: String, Codable {
    case pass
    case borderline
    case fail
}

/// A measurement evaluated against the rules: value, limit, signed margin, state.
public struct EvaluatedMeasurement: Equatable, Codable, Identifiable {
    public let kind: MeasurementKind
    public let value: Double
    public let limit: Double
    public let direction: LimitDirection
    /// Signed margin to the limit, in the measurement's unit. Positive == inside
    /// the limit (good), negative == outside (fail). For a `max` limit this is
    /// `limit − value`; for a `min` limit it is `value − limit`.
    public let margin: Double
    public let state: MeasurementState

    public var id: String { kind.rawValue }

    public var unit: String { kind.unit }
}

/// Turns raw measurements into evaluated ones using the active category + rules.
public enum Evaluator {

    public static func evaluate(measurements: [Measurement],
                                category: UCICategory,
                                rules: UCIRules = .current) -> [EvaluatedMeasurement] {
        let catLimits = rules.limits(for: category)
        return measurements.compactMap { m in
            switch m.kind {
            case .reach:
                return make(m, limit: catLimits.reachMaxMm, direction: .max, rules: rules)
            case .extensionHeight:
                return make(m, limit: catLimits.heightMaxMm, direction: .max, rules: rules)
            case .armToTip:
                return make(m, limit: rules.armToTipMinMm, direction: .min, rules: rules)
            case .armrestAngle:
                return make(m, limit: rules.armrestAngleMaxDeg, direction: .max,
                            rules: rules, isAngle: true)
            case .saddleSetback:
                // Setback isn't pass/fail on its own (it selects the category and
                // has a morphological-exemption minimum we don't hard-encode).
                // Report it informationally with no enforced limit.
                return EvaluatedMeasurement(
                    kind: .saddleSetback, value: m.value, limit: .nan,
                    direction: .min, margin: .nan, state: .pass)
            }
        }
    }

    private static func make(_ m: Measurement,
                             limit: Double,
                             direction: LimitDirection,
                             rules: UCIRules,
                             isAngle: Bool = false) -> EvaluatedMeasurement {
        let margin: Double
        switch direction {
        case .max: margin = limit - m.value      // positive == under the ceiling
        case .min: margin = m.value - limit      // positive == over the floor
        }

        let band = isAngle ? rules.borderlineMarginDeg : rules.borderlineMarginMm
        let state: MeasurementState
        if margin < 0 {
            state = .fail
        } else if margin <= band {
            state = .borderline
        } else {
            state = .pass
        }

        return EvaluatedMeasurement(kind: m.kind, value: m.value, limit: limit,
                                    direction: direction, margin: margin, state: state)
    }
}
