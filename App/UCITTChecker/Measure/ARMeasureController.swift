import Foundation
import ARKit
import SceneKit
import UCITTCore

/// Drives the ARKit measuring session: owns the AR view, the guided landmark
/// order, and the captured gravity-aligned 3D points (stored in mm).
///
/// ARKit's default world alignment is `.gravity`, so +y is up and x/z span the
/// horizontal plane — exactly what `Point3` expects. On LiDAR devices we enable
/// scene-mesh reconstruction so raycasts hit real geometry; without it we fall
/// back to estimated planes.
@MainActor
final class ARMeasureController: NSObject, ObservableObject {

    @Published var points: [Landmark: Point3] = [:]
    @Published var activeIndex: Int = 0
    @Published var trackingNormal: Bool = false
    @Published var lastCaptureFailed: Bool = false

    let order = Landmark.captureOrder
    weak var arView: ARSCNView?

    var active: Landmark { order[min(activeIndex, order.count - 1)] }
    var allPlaced: Bool { order.allSatisfy { points[$0] != nil } }
    var placedCount: Int { order.filter { points[$0] != nil }.count }

    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    func start() {
        guard let arView else { return }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() { arView?.session.pause() }

    /// Capture the current landmark by raycasting from the screen-center reticle.
    func captureCurrent() {
        guard let arView else { return }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        // Prefer existing geometry (LiDAR mesh / detected planes); fall back to
        // an estimated plane so it still works on non-LiDAR devices.
        let targets: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]
        var hit: ARRaycastResult?
        for target in targets {
            guard let query = arView.raycastQuery(from: center, allowing: target, alignment: .any)
            else { continue }
            if let result = arView.session.raycast(query).first { hit = result; break }
        }

        guard let hit else {
            lastCaptureFailed = true
            return
        }
        lastCaptureFailed = false

        let c = hit.worldTransform.columns.3
        points[active] = Point3(x: Double(c.x) * 1000.0,
                                y: Double(c.y) * 1000.0,
                                z: Double(c.z) * 1000.0)
        advance()
    }

    func select(_ landmark: Landmark) {
        activeIndex = order.firstIndex(of: landmark) ?? activeIndex
    }

    func undoActive() {
        points[active] = nil
    }

    private func advance() {
        if let next = order.firstIndex(where: { points[$0] == nil }) {
            activeIndex = next
        } else {
            activeIndex = order.count - 1
        }
    }
}

extension ARMeasureController: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let normal: Bool
        if case .normal = camera.trackingState { normal = true } else { normal = false }
        Task { @MainActor in self.trackingNormal = normal }
    }
}
