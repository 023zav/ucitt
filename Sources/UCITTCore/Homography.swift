import Foundation

/// A 3×3 planar projective transform mapping image pixels to real-world
/// millimetres in the marker's plane (and back).
///
/// The transform is recovered from four point correspondences — typically the
/// four detected marker corners (pixels) against the marker's known physical
/// corners (mm). Once built, every tapped landmark pixel is pushed through
/// `apply(_:)` to obtain a mm coordinate, after which all measurements are
/// metric distances/angles in that plane (see §3, §6 of the spec).
public struct Homography: Equatable {

    /// Row-major 3×3 matrix `[h0 h1 h2; h3 h4 h5; h6 h7 h8]` with `h8 == 1`.
    public let m: [Double]

    public init(matrix: [Double]) {
        precondition(matrix.count == 9, "Homography needs 9 elements")
        self.m = matrix
    }

    /// Apply the homography to a point: `dst ~ H * [x y 1]ᵀ`, de-homogenised.
    public func apply(_ p: Point2) -> Point2 {
        let x = p.x, y = p.y
        let w = m[6] * x + m[7] * y + m[8]
        let X = (m[0] * x + m[1] * y + m[2]) / w
        let Y = (m[3] * x + m[4] * y + m[5]) / w
        return Point2(x: X, y: Y)
    }

    /// The four corners of a marker of the given physical size, in mm, in the
    /// order corresponding to a clockwise top-left, top-right, bottom-right,
    /// bottom-left image traversal.
    ///
    /// y increases downward to match image-corner ordering; this keeps the
    /// rectified plane right-handed with respect to the detected pixels.
    public static func markerCornersMM(width: Double, height: Double) -> [Point2] {
        [
            Point2(x: 0,     y: 0),       // top-left
            Point2(x: width, y: 0),       // top-right
            Point2(x: width, y: height),  // bottom-right
            Point2(x: 0,     y: height)   // bottom-left
        ]
    }

    /// Estimate the homography mapping `src` pixels to `dst` mm using the
    /// Direct Linear Transform on exactly four correspondences.
    ///
    /// Each correspondence contributes two rows to an 8×8 system in the
    /// unknowns `h0…h7` (with `h8` fixed to 1):
    ///
    ///     X = (h0·x + h1·y + h2) / (h6·x + h7·y + 1)
    ///     Y = (h3·x + h4·y + h5) / (h6·x + h7·y + 1)
    ///
    /// linearised to
    ///
    ///     h0·x + h1·y + h2 − h6·x·X − h7·y·X = X
    ///     h3·x + h4·y + h5 − h6·x·Y − h7·y·Y = Y
    ///
    /// - Returns: the homography, or `nil` if the four points are degenerate
    ///   (e.g. collinear) so the system is singular.
    public static func estimate(src: [Point2], dst: [Point2]) -> Homography? {
        guard src.count == 4, dst.count == 4 else { return nil }

        var A = [[Double]]()
        var b = [Double]()
        A.reserveCapacity(8)
        b.reserveCapacity(8)

        for i in 0..<4 {
            let x = src[i].x, y = src[i].y
            let X = dst[i].x, Y = dst[i].y
            A.append([x, y, 1, 0, 0, 0, -x * X, -y * X])
            b.append(X)
            A.append([0, 0, 0, x, y, 1, -x * Y, -y * Y])
            b.append(Y)
        }

        guard let h = LinearSolver.solve(A, b) else { return nil }
        return Homography(matrix: [h[0], h[1], h[2],
                                   h[3], h[4], h[5],
                                   h[6], h[7], 1.0])
    }
}
