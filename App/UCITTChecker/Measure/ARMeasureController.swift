import Foundation
import ARKit
import SceneKit
import simd
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
    /// Distance (m) from the camera to the most recent captured point.
    @Published var lastCaptureDistanceM: Double?

    let order = Landmark.captureOrder
    weak var arView: ARSCNView?
    /// Visible scene markers, one per placed landmark.
    private var nodes: [Landmark: SCNNode] = [:]

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
        let worldPos = simd_float3(c.x, c.y, c.z)

        // How far the captured point is from the camera. A TT bike is scanned
        // from ~1–1.5 m; a much larger distance usually means the ray slipped
        // past a thin part (tip/BB) and hit the wall/floor behind — surface the
        // number so the user can spot and re-do a bad capture.
        if let cam = arView.session.currentFrame?.camera.transform.columns.3 {
            let camPos = simd_float3(cam.x, cam.y, cam.z)
            lastCaptureDistanceM = Double(simd_distance(camPos, worldPos))
        } else {
            lastCaptureDistanceM = nil
        }

        points[active] = Point3(x: Double(worldPos.x) * 1000.0,
                                y: Double(worldPos.y) * 1000.0,
                                z: Double(worldPos.z) * 1000.0)
        addMarkerNode(at: worldPos, for: active)
        advance()
    }

    func select(_ landmark: Landmark) {
        activeIndex = order.firstIndex(of: landmark) ?? activeIndex
    }

    func undoActive() {
        nodes[active]?.removeFromParentNode()
        nodes[active] = nil
        points[active] = nil
    }

    /// Drop a visible sphere at a captured point so the user can verify it sits
    /// on the bike (not the background) and re-capture if it doesn't.
    private func addMarkerNode(at pos: simd_float3, for landmark: Landmark) {
        nodes[landmark]?.removeFromParentNode()
        let sphere = SCNSphere(radius: 0.008)   // 8 mm bead
        sphere.firstMaterial?.diffuse.contents = UIColor.systemOrange
        sphere.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: sphere)
        node.simdPosition = pos
        arView?.scene.rootNode.addChildNode(node)
        nodes[landmark] = node
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
