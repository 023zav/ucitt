import Foundation
import ARKit
import SceneKit
import CoreVideo
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

    private var didConfigure = false

    private func makeConfig() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        return config
    }

    func start() {
        guard let arView else { return }
        arView.session.delegate = self
        if didConfigure {
            // Returning to this screen (e.g. Back from Results): resume the same
            // session WITHOUT resetting tracking, so the world origin — and the
            // already-placed orange dots — stay locked to the real bike. A reset
            // here would detach every dot.
            arView.session.run(makeConfig())
        } else {
            didConfigure = true
            arView.session.run(makeConfig(), options: [.resetTracking, .removeExistingAnchors])
        }
    }

    func pause() { arView?.session.pause() }

    /// Discard all placed points and their scene markers (a fresh scan).
    func resetPoints() {
        for node in nodes.values { node.removeFromParentNode() }
        nodes.removeAll()
        points.removeAll()
        activeIndex = 0
        lastCaptureDistanceM = nil
        lastCaptureFailed = false
    }

    /// Capture the current landmark. Prefers the LiDAR depth at the reticle
    /// pixel (hits the actual surface you're pointing at, e.g. a thin tube),
    /// and falls back to a plane/mesh raycast on non-LiDAR devices.
    func captureCurrent() {
        guard let arView else { return }

        var worldPos: simd_float3?

        if let frame = arView.session.currentFrame {
            worldPos = depthWorldPoint(frame: frame)
        }

        if worldPos == nil {
            // Fallback: raycast to existing geometry / an estimated plane.
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
                guard let query = arView.raycastQuery(from: center, allowing: target, alignment: .any)
                else { continue }
                if let result = arView.session.raycast(query).first {
                    let c = result.worldTransform.columns.3
                    worldPos = simd_float3(c.x, c.y, c.z)
                    break
                }
            }
        }

        guard let worldPos else {
            lastCaptureFailed = true
            return
        }
        lastCaptureFailed = false

        // How far the captured point is from the camera. A TT bike is scanned
        // from ~1–1.5 m; a much larger distance usually means the aim slipped
        // past a thin part (tip/BB) onto the wall/floor behind — surface the
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

    /// World point from the LiDAR depth map at its center (≈ the reticle / the
    /// camera's optical axis). Reading depth at the aimed pixel hits the real
    /// surface there — a thin tube, the saddle nose — instead of punching
    /// through to a plane behind it, which is what corrupted the horizontal
    /// measurements. Returns nil when there's no depth (non-LiDAR device).
    private func depthWorldPoint(frame: ARFrame) -> simd_float3? {
        guard let depth = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap else {
            return nil
        }
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }

        let w = CVPixelBufferGetWidth(depth)
        let h = CVPixelBufferGetHeight(depth)
        guard let base = CVPixelBufferGetBaseAddress(depth) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(depth)

        // Sample a small patch at the center and take the NEAREST valid depth.
        // Aiming at a thin tube/tip, the reticle pixel can fall in the gap beside
        // it and read the wall behind; the nearest depth in the patch grabs the
        // foreground part you're actually pointing at.
        let cx = w / 2, cy = h / 2
        let half = max(2, Int(Double(min(w, h)) * 0.02))
        var best = Float32.greatestFiniteMagnitude
        for yy in max(0, cy - half)...min(h - 1, cy + half) {
            let row = base.advanced(by: yy * rowBytes).assumingMemoryBound(to: Float32.self)
            for xx in max(0, cx - half)...min(w - 1, cx + half) {
                let v = row[xx]
                if v.isFinite, v > 0.05, v < 5.0, v < best { best = v }
            }
        }
        guard best < Float32.greatestFiniteMagnitude else { return nil }
        let d = best   // metres, nearest surface at the reticle

        // The image center ≈ the camera's optical axis, so the surface point is
        // straight ahead at distance d in camera space (ARKit camera looks -z).
        let world = frame.camera.transform * simd_float4(0, 0, -d, 1)
        return simd_float3(world.x, world.y, world.z)
    }

    func select(_ landmark: Landmark) {
        activeIndex = order.firstIndex(of: landmark) ?? activeIndex
    }

    func undoActive() {
        nodes[active]?.removeFromParentNode()
        nodes[active] = nil
        points[active] = nil
    }

    /// Drop a visible, numbered sphere at a captured point so the user can
    /// verify it sits on the bike (not the background) and re-capture if it
    /// doesn't. The number matches the landmark's order (1…6), so a screenshot
    /// of all dots can be checked at a glance.
    private func addMarkerNode(at pos: simd_float3, for landmark: Landmark) {
        nodes[landmark]?.removeFromParentNode()
        let number = (order.firstIndex(of: landmark) ?? 0) + 1

        let sphere = SCNSphere(radius: 0.008)   // 8 mm bead
        sphere.firstMaterial?.diffuse.contents = UIColor.systemOrange
        sphere.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: sphere)
        node.simdPosition = pos

        // Billboarded number floating just above the bead.
        let text = SCNText(string: "\(number)", extrusionDepth: 0)
        text.font = UIFont.boldSystemFont(ofSize: 10)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.lightingModel = .constant
        let textNode = SCNNode(geometry: text)
        let (minB, maxB) = text.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2,
                                                   (minB.y + maxB.y) / 2, 0)
        textNode.scale = SCNVector3(0.0016, 0.0016, 0.0016)
        textNode.position = SCNVector3(0, 0.022, 0)   // ~22 mm above the bead
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        node.addChildNode(textNode)

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
