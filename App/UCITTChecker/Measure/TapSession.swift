import SwiftUI
import UCITTCore

/// Drives the guided, one-at-a-time landmark tapping (§4 S4). Points are stored
/// in the captured image's pixel coordinate space so they feed the homography
/// directly. The UI converts between view space and image space.
@MainActor
final class TapSession: ObservableObject {

    /// Placed points, keyed by landmark, in image pixels.
    @Published var points: [Landmark: Point2] = [:]
    /// Index into `Landmark.captureOrder` of the landmark currently being placed.
    @Published var activeIndex: Int = 0
    /// Whether a drag is in progress (drives loupe visibility).
    @Published var isAdjusting: Bool = false

    let order = Landmark.captureOrder

    init(existing: [Landmark: Point2] = [:]) {
        points = existing
        // Resume at the first unplaced landmark.
        activeIndex = order.firstIndex { points[$0] == nil } ?? order.count - 1
    }

    var active: Landmark { order[min(activeIndex, order.count - 1)] }

    var allPlaced: Bool { order.allSatisfy { points[$0] != nil } }

    var placedCount: Int { order.filter { points[$0] != nil }.count }

    /// Place or move the active landmark.
    func setActivePoint(_ p: Point2) {
        points[active] = p
    }

    /// Move a specific landmark (used when dragging an already-placed point).
    func move(_ landmark: Landmark, to p: Point2) {
        points[landmark] = p
        activeIndex = order.firstIndex(of: landmark) ?? activeIndex
    }

    /// Advance to the next unplaced landmark (or stay on the last).
    func advance() {
        if let next = order.firstIndex(where: { points[$0] == nil }) {
            activeIndex = next
        } else {
            activeIndex = order.count - 1
        }
    }
}
