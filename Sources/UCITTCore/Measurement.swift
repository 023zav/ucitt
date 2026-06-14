import Foundation

/// The cockpit measurements the MVP produces (§1, §5).
public enum MeasurementKind: String, CaseIterable, Codable, Identifiable {
    case reach
    case extensionHeight
    case armToTip
    case armrestAngle
    case saddleSetback

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .reach:          return "Reach"
        case .extensionHeight: return "Extension height"
        case .armToTip:       return "Armrest → tip"
        case .armrestAngle:   return "Armrest angle"
        case .saddleSetback:  return "Saddle setback"
        }
    }

    /// Unit used for display.
    public var unit: String {
        self == .armrestAngle ? "°" : "mm"
    }
}

/// A raw measured value (before rules are applied).
public struct Measurement: Equatable, Codable {
    public let kind: MeasurementKind
    /// Value in mm, except `armrestAngle` which is in degrees.
    public let value: Double

    public init(kind: MeasurementKind, value: Double) {
        self.kind = kind
        self.value = value
    }
}

public extension Measurement {
    /// Compute all five raw measurements from the six landmark points, in the
    /// rectified mm plane. Formulas mirror §5 exactly.
    ///
    /// `reach` and `armToTip` are inherently positive horizontal distances, so
    /// their magnitude is taken — this makes the result independent of whether
    /// the marker's +x axis happens to point toward the front or rear of the
    /// bike. `saddleSetback` keeps its sign relative to the BB but is reported
    /// as magnitude (positive == saddle nose behind the BB is the common case);
    /// the category engine only cares about its magnitude.
    static func all(points: [Landmark: Point2]) -> [Measurement]? {
        guard
            let bb = points[.bb],
            let tip = points[.tip],
            let armMid = points[.armMid],
            let armLead = points[.armLead],
            let armRear = points[.armRear],
            let saddleNose = points[.saddleNose]
        else { return nil }

        let reach = abs(Geometry.horizontal(tip, bb))
        let height = abs(Geometry.vertical(armMid, tip))
        let armToTip = abs(Geometry.horizontal(tip, armLead))
        let angle = Geometry.inclinationDegrees(armLead, armRear)
        let setback = abs(Geometry.horizontal(bb, saddleNose))

        return [
            Measurement(kind: .reach, value: reach),
            Measurement(kind: .extensionHeight, value: height),
            Measurement(kind: .armToTip, value: armToTip),
            Measurement(kind: .armrestAngle, value: angle),
            Measurement(kind: .saddleSetback, value: setback)
        ]
    }
}
