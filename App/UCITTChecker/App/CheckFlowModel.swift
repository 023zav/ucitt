import SwiftUI
import UIKit
import UCITTCore

/// The screens of the guided flow (§4).
enum FlowStep: Hashable {
    case onboarding
    case riderInput
    case capture
    case cardCorners
    case tapping
    case arkit
    case results
}

/// Single source of truth for the whole check, shared across screens.
@MainActor
final class CheckFlowModel: ObservableObject {

    // Navigation
    @Published var path: [FlowStep] = []

    // Rider inputs (§4 S2)
    @Published var heightCm: Double = 178
    @Published var useSetbackOverride: Bool = false
    @Published var setbackOverrideMm: Double = 60

    // How we get real-world scale (§6). LiDAR scan is primary; bank card is the
    // fallback for phones without LiDAR.
    @Published var mode: MeasurementMode = .arKit

    // Capture output (bank-card photo mode)
    @Published var capturedImage: UIImage?
    @Published var markerCornersPx: [Point2] = []
    @Published var captureRejection: MarkerGeometry.Rejection?

    // Tapping output: landmark -> pixel in the captured image's coordinate space.
    @Published var landmarkPx: [Landmark: Point2] = [:]

    // ARKit mode: landmark -> gravity-aligned world point in mm.
    @Published var landmark3D: [Landmark: Point3] = [:]

    // Result
    @Published var report: ResultReport?
    @Published var checkError: PositionChecker.Failure?
    /// Human-readable debug dump of the most recent successful run.
    @Published var lastDebugText: String = ""

    private var checker: PositionChecker {
        PositionChecker(rules: .current,
                        markerWidthMM: BankCard.widthMM,
                        markerHeightMM: BankCard.heightMM)
    }

    func start() { path = [] } // root shows onboarding

    func advance(to step: FlowStep) { path.append(step) }

    func reset() {
        capturedImage = nil
        markerCornersPx = []
        captureRejection = nil
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

    /// Run the pure pipeline and store the report (or error).
    func computeResult() {
        guard let image = capturedImage else { return }
        let w = Double(image.size.width * image.scale)
        let h = Double(image.size.height * image.scale)
        let override = useSetbackOverride ? setbackOverrideMm : nil

        let result = checker.check(markerCornersPx: markerCornersPx,
                                   landmarksPx: landmarkPx,
                                   heightCm: heightCm,
                                   setbackOverrideMm: override,
                                   frameWidth: w,
                                   frameHeight: h,
                                   // Capture was already validated at S3; don't
                                   // re-reject here.
                                   validateCapture: false)
        switch result {
        case .success(let r):
            report = r
            checkError = nil
            logRun(report: r, points3D: [:])   // card mode has no 3D points
        case .failure(let e):
            report = nil
            checkError = e
        }
    }
}
