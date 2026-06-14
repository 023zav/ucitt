import Foundation

/// Determines the UCI category from rider height and measured saddle setback,
/// and surfaces the non-hard-fail flags (§7).
public enum CategoryEngine {

    /// The category plus a short, user-facing explanation of *why*.
    public struct Decision: Equatable {
        public let category: UCICategory
        public let reason: String
        public let flags: [String]
    }

    /// Apply the category logic of §7.
    /// - Parameters:
    ///   - heightCm: rider height in centimetres.
    ///   - saddleSetbackMm: measured (or overridden) saddle setback, magnitude in mm.
    ///   - rules: the active rule set.
    public static func decide(heightCm: Double,
                              saddleSetbackMm: Double,
                              rules: UCIRules = .current) -> Decision {
        var flags: [String] = []

        // Cat 2/3 require a UCI application + frame sticker; without it the rider
        // is held to Forward limits. We surface this as a flag rather than
        // silently downgrading, so the user can decide.
        if heightCm >= rules.stickerRequiredHeightCm {
            flags.append(
                "Rider height ≥ \(Int(rules.stickerRequiredHeightCm)) cm: Cat 2/3 " +
                "limits require a UCI online application form and a frame sticker " +
                "before the event. Without it, the rider is held to Forward limits."
            )
        }

        // Saddle-setback minimum-distance rule has a morphological exemption and
        // is not hard-encoded here (spec: verify against current rulebook).
        flags.append(
            "Saddle setback also has its own minimum-distance rule (with a " +
            "morphological exemption). Verify against the current UCI rulebook."
        )

        let category: UCICategory
        let reason: String

        if saddleSetbackMm < rules.forwardSetbackThresholdMm {
            category = .forward
            reason = "Saddle setback \(mm(saddleSetbackMm)) < " +
                     "\(mm(rules.forwardSetbackThresholdMm)) → Forward position."
        } else if heightCm < rules.cat2MinHeightCm {
            category = .cat1
            reason = "Rider height \(cm(heightCm)) < " +
                     "\(cm(rules.cat2MinHeightCm)) → Cat 1."
        } else if heightCm < rules.cat3MinHeightCm {
            category = .cat2
            reason = "Rider height \(cm(heightCm)) in " +
                     "[\(cm(rules.cat2MinHeightCm)), \(cm(rules.cat3MinHeightCm))) → Cat 2."
        } else {
            category = .cat3
            reason = "Rider height \(cm(heightCm)) ≥ " +
                     "\(cm(rules.cat3MinHeightCm)) → Cat 3."
        }

        return Decision(category: category, reason: reason, flags: flags)
    }

    private static func mm(_ v: Double) -> String { "\(Int(v.rounded())) mm" }
    private static func cm(_ v: Double) -> String {
        // Trim trailing .0 for whole numbers.
        v == v.rounded() ? "\(Int(v)) cm" : String(format: "%.1f cm", v)
    }
}
