import Foundation

/// The bike category a position falls into. Drives the reach/height limits.
public enum UCICategory: String, Codable, CaseIterable {
    case forward = "Forward"
    case cat1 = "Cat 1"
    case cat2 = "Cat 2"
    case cat3 = "Cat 3"

    public var displayName: String { rawValue }
}

/// Whether a measurement must stay under a maximum or over a minimum.
public enum LimitDirection: String, Codable {
    case max
    case min
}

/// All UCI numeric limits, kept in one place and data-driven so they can be
/// bumped when the UCI revises them (§7). `rulesVersion` is stamped onto every
/// report. Values are current-as-of 2024/25 per the spec brief and are NOT a
/// legal source — treat as an estimate baseline.
public struct UCIRules: Codable, Equatable {

    /// Per-category reach + extension-height ceilings (mm).
    public struct CategoryLimits: Codable, Equatable {
        public let reachMaxMm: Double
        public let heightMaxMm: Double
        public init(reachMaxMm: Double, heightMaxMm: Double) {
            self.reachMaxMm = reachMaxMm
            self.heightMaxMm = heightMaxMm
        }
    }

    public let rulesVersion: String

    /// Saddle-setback threshold (mm) below which the "Forward" category applies.
    public let forwardSetbackThresholdMm: Double
    /// Rider-height thresholds (cm) selecting Cat 1 / 2 / 3.
    public let cat2MinHeightCm: Double   // ≥ this and < cat3 → Cat 2
    public let cat3MinHeightCm: Double   // ≥ this → Cat 3

    public let forward: CategoryLimits
    public let cat1: CategoryLimits
    public let cat2: CategoryLimits
    public let cat3: CategoryLimits

    /// Fixed limits that apply to every category.
    public let armToTipMinMm: Double
    public let armrestAngleMaxDeg: Double

    /// Height (cm) at/above which the rider needs the Cat 2/3 UCI application +
    /// frame sticker, else they are held to Forward limits (§7 flags).
    public let stickerRequiredHeightCm: Double

    /// A measurement is "borderline" when within this margin of its limit (§7).
    public let borderlineMarginMm: Double
    /// Borderline band for the angle limit (degrees).
    public let borderlineMarginDeg: Double

    public func limits(for category: UCICategory) -> CategoryLimits {
        switch category {
        case .forward: return forward
        case .cat1:    return cat1
        case .cat2:    return cat2
        case .cat3:    return cat3
        }
    }

    /// The current default rule set (spec §7).
    public static let current = UCIRules(
        rulesVersion: "2024-25-mvp",
        forwardSetbackThresholdMm: 50,
        cat2MinHeightCm: 180,
        cat3MinHeightCm: 190,
        forward: CategoryLimits(reachMaxMm: 750, heightMaxMm: 100),
        cat1:    CategoryLimits(reachMaxMm: 800, heightMaxMm: 100),
        cat2:    CategoryLimits(reachMaxMm: 830, heightMaxMm: 120),
        cat3:    CategoryLimits(reachMaxMm: 850, heightMaxMm: 140),
        armToTipMinMm: 180,
        armrestAngleMaxDeg: 30,
        stickerRequiredHeightCm: 180,
        borderlineMarginMm: 10,
        borderlineMarginDeg: 2
    )
}
