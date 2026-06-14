import Foundation

/// A 2D point. Used for both image pixels and rectified world millimetres;
/// the unit is whatever the caller is working in. After a `Homography` is
/// applied, points are in millimetres in the marker's level plane, where
/// +x is world-horizontal and +y is world-vertical.
public struct Point2: Equatable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static func - (lhs: Point2, rhs: Point2) -> Point2 {
        Point2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func + (lhs: Point2, rhs: Point2) -> Point2 {
        Point2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Euclidean length from origin.
    public var magnitude: Double { (x * x + y * y).squareRoot() }
}

public enum Geometry {

    /// Straight-line distance between two points (in their shared unit).
    public static func distance(_ a: Point2, _ b: Point2) -> Double {
        (a - b).magnitude
    }

    /// Signed horizontal separation `a.x - b.x`.
    public static func horizontal(_ a: Point2, _ b: Point2) -> Double {
        a.x - b.x
    }

    /// Signed vertical separation `a.y - b.y`.
    public static func vertical(_ a: Point2, _ b: Point2) -> Double {
        a.y - b.y
    }

    /// Angle of the directed segment `from -> to` relative to world horizontal,
    /// in degrees, in the range (-180, 180]. Because the working plane is
    /// world-aligned, "horizontal" is the rectified +x axis.
    ///
    /// Note on the rectified frame: a `Homography` built with
    /// `Homography.markerCornersMM` puts +y pointing *down* (image convention).
    /// For an armrest whose rear edge sits higher than its leading edge that
    /// makes the raw angle negative, so callers that only care about tilt
    /// magnitude (the UCI 30° limit) should use `abs`.
    public static func angleDegrees(from: Point2, to: Point2) -> Double {
        let d = to - from
        return atan2(d.y, d.x) * 180.0 / Double.pi
    }

    /// Acute inclination of the segment `a–b` to world horizontal, in degrees,
    /// in the range [0, 90]. This is direction-agnostic: it is the same whether
    /// the segment is given front-to-rear or rear-to-front, which is what the
    /// UCI armrest-angle limit (max 30° tilt from horizontal) actually cares
    /// about. Using the raw `angleDegrees` here would be wrong whenever the
    /// rear edge sits behind the leading edge (angle would land near ±180°).
    public static func inclinationDegrees(_ a: Point2, _ b: Point2) -> Double {
        let d = b - a
        return atan2(abs(d.y), abs(d.x)) * 180.0 / Double.pi
    }
}
