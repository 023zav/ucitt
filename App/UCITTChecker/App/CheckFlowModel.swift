import SwiftUI
import UIKit
import UCITTCore

/// The screens of the guided flow.
enum FlowStep: Hashable {
    case onboarding
    case riderInput
    case capture
    case wheelReference
    case tapping
    case arkit
    case results
}

/// Single source of truth for the whole check, shared across screens.
@MainActor
final class CheckFlowModel: ObservableObject {

    // Navigation
    @Published var path: [FlowStep] = []

    // Rider inputs
    @Published var heightCm: Double = 178
    @Published var useSetbackOverride: Bool = false
    @Published var setbackOverrideMm: Double = 60

    // How we get real-world scale. LiDAR is primary; wheel photo is the
    // markerless fallback / cross-check for any phone.
    @Published var mode: MeasurementMode = .arKit
    @Published var wheelSize: WheelSize = .road700x25

    // Capture output (wheel photo mode)
    @Published var capturedImage: UIImage?
    /// Wheel reference taps (pixels): rear hub, front hub, rear ground contact.
    @Published var rearHubPx: Point2?
    @Published var frontHubPx: Point2?
    @Published var groundContactPx: Point2?

    // Tapping output: landmark -> pixel in the captured image's coordinate space.
    @Published var landmarkPx: [Landmark: Point2] = [:]

    // ARKit mode: landmark -> gravity-aligned world point in mm.
    @Published var landmark3D: [Landmark: Point3] = [:]

    // Result
    @Published var report: ResultReport?
    @Published var checkError: PositionChecker.Failure?
    /// Human-readable debug dump of the most recent successful run.
    @Published var lastDebugText: String = ""

    private var checker: PositionChecker { PositionChecker(rules: .current) }

    func start() { path = [] } // root shows onboarding

    func advance(to step: FlowStep) { path.append(step) }

    func reset() {
        capturedImage = nil
        rearHubPx = nil
        frontHubPx = nil
        groundContactPx = nil
        landmarkPx = [:]
        landmark3D = [:]
        report = nil
        checkError = nil
        path = []
    }

    /// First flow step after rider input, depending on the chosen mode.
    var captureStep: FlowStep {
        mode == .arKit ? .arkit : .capture
    }

    /// Have all three wheel reference points been placed?
    var wheelReferencePlaced: Bool {
        rearHubPx != nil && frontHubPx != nil && groundContactPx != nil
    }

    /// ARKit path: compute the report from collected 3D landmark points.
    func computeResultFromARKit() {
        let override = useSetbackOverride ? setbackOverrideMm : nil
        switch checker.check(points3: landmark3D,
                             heightCm: heightCm,
                             setbackOverrideMm: override) {
        case .success(let r):
            report = r; checkError = nil
            logRun(report: r, points3D: landmark3D)
        case .failure(let e): report = nil; checkError = e
        }
    }

    /// Wheel-photo path: scale from the bike's wheel, then evaluate the landmarks.
    func computeResultFromWheel() {
        guard let rear = rearHubPx, let front = frontHubPx, let ground = groundContactPx else {
            checkError = .missingLandmarks; report = nil; return
        }
        let override = useSetbackOverride ? setbackOverrideMm : nil
        switch checker.check(landmarksPx: landmarkPx,
                             rearHubPx: rear, frontHubPx: front, groundContactPx: ground,
                             wheelDiameterMM: wheelSize.diameterMM,
                             heightCm: heightCm,
                             setbackOverrideMm: override) {
        case .success(let r):
            report = r; checkError = nil
            logRun(report: r, points3D: [:])
        case .failure(let e): report = nil; checkError = e
        }
    }

    /// Record a successful run to the persistent debug log and stash a readable
    /// dump for the Results screen.
    private func logRun(report: ResultReport, points3D: [Landmark: Point3]) {
        let record = RunRecord(mode: mode.rawValue,
                               heightCm: heightCm,
                               report: report,
                               points3D: points3D)
        RunLog.append(record)
        lastDebugText = RunLog.text(for: record, points3D: points3D)
    }

    /// All six landmarks placed?
    var allLandmarksPlaced: Bool {
        Landmark.captureOrder.allSatisfy { landmarkPx[$0] != nil }
    }
}
