import Foundation

/// Pure geometric checks on a detected marker. The actual pixel detection
/// (ArUco / Vision) lives in the app layer; this is the device-independent
/// validation that decides whether a capture is good enough to measure from.
public enum MarkerGeometry {

    /// Why a capture was rejected.
    public enum Rejection: Equatable {
        case notLevel(tiltDegrees: Double)
        case tooSmall(coveragePercent: Double)
        case tooMuchPerspective(skew: Double)
        case wrongCornerCount(Int)
    }

    /// Tilt of the marker's top edge from horizontal, in degrees [0, 90].
    /// Corners are expected in TL, TR, BR, BL order (pixels).
    public static func tiltDegrees(corners: [Point2]) -> Double {
        guard corners.count == 4 else { return .nan }
        // Average the two horizontal edges (top TL->TR and bottom BL->BR) for a
        // more stable estimate than a single edge.
        let topTilt = Geometry.inclinationDegrees(corners[0], corners[1])
        let bottomTilt = Geometry.inclinationDegrees(corners[3], corners[2])
        return (topTilt + bottomTilt) / 2.0
    }

    /// A 0…1 measure of how square the detected quad is. A perfect fronto-
    /// parallel square is ~0; heavy perspective pushes it up. Computed as the
    /// relative difference between opposite-edge lengths.
    public static func perspectiveSkew(corners: [Point2]) -> Double {
        guard corners.count == 4 else { return .nan }
        let top = Geometry.distance(corners[0], corners[1])
        let bottom = Geometry.distance(corners[3], corners[2])
        let left = Geometry.distance(corners[0], corners[3])
        let right = Geometry.distance(corners[1], corners[2])
        let hSkew = ratioDiff(top, bottom)
        let vSkew = ratioDiff(left, right)
        return max(hSkew, vSkew)
    }

    /// Fraction (0…1) of the frame's *shorter* dimension spanned by the marker's
    /// average edge — a rough "is the marker big enough" proxy.
    public static func coverage(corners: [Point2], frameWidth: Double, frameHeight: Double) -> Double {
        guard corners.count == 4, frameWidth > 0, frameHeight > 0 else { return .nan }
        let edges = [
            Geometry.distance(corners[0], corners[1]),
            Geometry.distance(corners[1], corners[2]),
            Geometry.distance(corners[2], corners[3]),
            Geometry.distance(corners[3], corners[0])
        ]
        let avgEdge = edges.reduce(0, +) / 4.0
        return avgEdge / min(frameWidth, frameHeight)
    }

    /// Validate a detected marker against capture-quality thresholds (§3, §6).
    /// - Parameters:
    ///   - corners: detected marker corners (pixels), TL/TR/BR/BL.
    ///   - frameWidth/Height: capture dimensions in pixels.
    ///   - maxTiltDeg: reject above this tilt (spec suggests ~1°).
    ///   - minCoverage: reject if marker spans less than this fraction.
    ///   - maxSkew: reject above this perspective skew.
    /// - Returns: `nil` if acceptable, otherwise the reason.
    public static func validate(corners: [Point2],
                                frameWidth: Double,
                                frameHeight: Double,
                                maxTiltDeg: Double = 1.0,
                                minCoverage: Double = 0.12,
                                maxSkew: Double = 0.15) -> Rejection? {
        guard corners.count == 4 else { return .wrongCornerCount(corners.count) }

        let tilt = tiltDegrees(corners: corners)
        if tilt > maxTiltDeg { return .notLevel(tiltDegrees: tilt) }

        let cov = coverage(corners: corners, frameWidth: frameWidth, frameHeight: frameHeight)
        if cov < minCoverage { return .tooSmall(coveragePercent: cov * 100) }

        let skew = perspectiveSkew(corners: corners)
        if skew > maxSkew { return .tooMuchPerspective(skew: skew) }

        return nil
    }

    private static func ratioDiff(_ a: Double, _ b: Double) -> Double {
        let m = max(a, b)
        guard m > 0 else { return 0 }
        return abs(a - b) / m
    }
}
