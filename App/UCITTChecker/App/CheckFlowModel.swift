import SwiftUI
import UIKit
import UCITTCore

/// The screens of the guided flow (§4).
enum FlowStep: Hashable {
    case onboarding
    case riderInput
    case capture
    case tapping
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

    // Marker config (§6) — user confirms the printed size.
    @Published var markerWidthMM: Double = 100
    @Published var markerHeightMM: Double = 100

    // Capture output
    @Published var capturedImage: UIImage?
    @Published var markerCornersPx: [Point2] = []
    @Published var captureRejection: MarkerGeometry.Rejection?

    // Tapping output: landmark -> pixel in the captured image's coordinate space.
    @Published var landmarkPx: [Landmark: Point2] = [:]

    // Result
    @Published var report: ResultReport?
    @Published var checkError: PositionChecker.Failure?

    private var checker: PositionChecker {
        PositionChecker(rules: .current,
                        markerWidthMM: markerWidthMM,
                        markerHeightMM: markerHeightMM)
    }

    func start() { path = [] } // root shows onboarding

    func advance(to step: FlowStep) { path.append(step) }

    func reset() {
        capturedImage = nil
        markerCornersPx = []
        captureRejection = nil
        landmarkPx = [:]
        report = nil
        checkError = nil
        path = []
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
        case .failure(let e):
            report = nil
            checkError = e
        }
    }
}
