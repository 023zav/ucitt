import Foundation

/// The full, shareable result of a check (§4 S5).
public struct ResultReport: Equatable, Codable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let rulesVersion: String

    public let heightCm: Double
    public let category: UCICategory
    public let categoryReason: String
    public let flags: [String]

    public let measurements: [EvaluatedMeasurement]

    /// The persistent disclaimer shown with every report (§1, §5, §9).
    public static let disclaimer =
        "Estimate only — not a UCI certification. Accuracy is roughly ±10 mm and " +
        "depends on marker placement. Any measurement within ~10 mm of a limit " +
        "(shown as “borderline”) must be re-checked with proper tools before a race."

    public var disclaimer: String { ResultReport.disclaimer }

    public init(id: UUID = UUID(),
                createdAt: Date = Date(),
                rulesVersion: String,
                heightCm: Double,
                category: UCICategory,
                categoryReason: String,
                flags: [String],
                measurements: [EvaluatedMeasurement]) {
        self.id = id
        self.createdAt = createdAt
        self.rulesVersion = rulesVersion
        self.heightCm = heightCm
        self.category = category
        self.categoryReason = categoryReason
        self.flags = flags
        self.measurements = measurements
    }

    /// Overall worst-case state across enforced measurements, for a headline.
    public var overallState: MeasurementState {
        if measurements.contains(where: { $0.state == .fail }) { return .fail }
        if measurements.contains(where: { $0.state == .borderline }) { return .borderline }
        return .pass
    }
}
