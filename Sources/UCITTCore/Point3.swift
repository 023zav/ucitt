import Foundation

/// A 3D point in millimetres in a gravity-aligned world frame: +y is up
/// (against gravity), x and z span the horizontal plane. Used by the ARKit
/// measurement path, where world-space landmark positions come straight from
/// the AR session (converted from metres to mm).
///
/// All MVP measurements need only two derived quantities from such points:
/// horizontal distance (in the ground plane) and vertical separation (along
/// gravity). The bike's fore-aft axis doesn't need to be known, because for a
/// roughly side-on rig the horizontal separation between two cockpit points is
/// their ground-plane distance.
public struct Point3: Equatable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Distance in the horizontal (ground) plane, ignoring height.
    public func horizontalDistance(to other: Point3) -> Double {
        let dx = x - other.x
        let dz = z - other.z
        return (dx * dx + dz * dz).squareRoot()
    }

    /// Absolute vertical separation along gravity.
    public func verticalDistance(to other: Point3) -> Double {
        abs(y - other.y)
    }
}
