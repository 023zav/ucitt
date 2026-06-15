import Foundation

/// Builds a similarity transform (uniform scale + rotation) from the bike's
/// wheel, used as a markerless scale reference instead of a placed marker.
///
/// Inputs (pixels): the two wheel hub centers and one wheel's ground-contact
/// point, plus the wheel's known outer diameter (mm). The hub-to-hub line is
/// real-world horizontal (the bike stands on level ground); the hub-to-ground
/// distance is the wheel radius, which sets metric scale.
///
/// Unlike a homography this does NOT correct perspective, so it assumes a
/// roughly square-on side view (camera a few metres back). Good for a pre-check.
public struct WheelRectifier: Equatable {
    public let origin: Point2     // rear hub (pixels)
    public let uHat: Point2       // world-horizontal unit vector, in pixel space
    public let vHat: Point2       // world-vertical (up) unit vector, in pixel space
    public let mmPerPixel: Double

    public init?(rearHub: Point2, frontHub: Point2, groundContact: Point2,
                 wheelDiameterMM: Double) {
        let axis = frontHub - rearHub
        let axisLen = axis.magnitude
        let radiusPx = (rearHub - groundContact).magnitude
        guard axisLen > 1e-6, radiusPx > 1e-6, wheelDiameterMM > 0 else { return nil }

        let u = Point2(x: axis.x / axisLen, y: axis.y / axisLen)
        // Perpendicular to u; choose the one pointing "up" (negative image y).
        var v = Point2(x: -u.y, y: u.x)
        if v.y > 0 { v = Point2(x: u.y, y: -u.x) }

        self.origin = rearHub
        self.uHat = u
        self.vHat = v
        self.mmPerPixel = (wheelDiameterMM / 2.0) / radiusPx
    }

    /// Map a pixel point into world mm: x along horizontal, y along vertical (up).
    public func mm(_ p: Point2) -> Point2 {
        let rel = p - origin
        let x = (rel.x * uHat.x + rel.y * uHat.y) * mmPerPixel
        let y = (rel.x * vHat.x + rel.y * vHat.y) * mmPerPixel
        return Point2(x: x, y: y)
    }
}

/// Common wheel/tyre outer diameters (mm), for the rider to pick from.
public enum WheelSize: String, CaseIterable, Identifiable, Codable {
    case road700x25
    case road700x28
    case road700x23
    case tt700x25

    public var id: String { rawValue }

    /// Approximate outer diameter in mm (bead-seat 622 + 2× tyre height).
    public var diameterMM: Double {
        switch self {
        case .road700x23: return 668
        case .road700x25: return 672
        case .tt700x25:   return 672
        case .road700x28: return 678
        }
    }

    public var displayName: String {
        switch self {
        case .road700x23: return "700 × 23c"
        case .road700x25: return "700 × 25c"
        case .tt700x25:   return "700 × 25c (TT)"
        case .road700x28: return "700 × 28c"
        }
    }
}
