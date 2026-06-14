import XCTest
@testable import UCITTCore

final class PositionCheckerTests: XCTestCase {

    // Synthetic imaging model: pixel = mm * scale + offset (no perspective),
    // which the homography inverts exactly, so recovered measurements equal
    // the mm we put in.
    private let scale = 2.0
    private let offset = Point2(x: 50, y: 50)

    private func toPx(_ mm: Point2) -> Point2 {
        Point2(x: mm.x * scale + offset.x, y: mm.y * scale + offset.y)
    }

    private func scenario() -> (corners: [Point2], landmarks: [Landmark: Point2]) {
        let cornersMM = Homography.markerCornersMM(width: 100, height: 100)
        let corners = cornersMM.map(toPx)

        let mm: [Landmark: Point2] = [
            .bb: Point2(x: 100, y: 600),
            .tip: Point2(x: 800, y: 300),
            .armMid: Point2(x: 700, y: 200),
            .armLead: Point2(x: 600, y: 250),
            // 10° tilt, 100mm run.
            .armRear: Point2(x: 700, y: 250 + 100 * tan(10 * .pi / 180)),
            .saddleNose: Point2(x: 20, y: 550)
        ]
        let landmarks = mm.mapValues(toPx)
        return (corners, landmarks)
    }

    private func value(_ report: ResultReport, _ kind: MeasurementKind) -> Double {
        report.measurements.first { $0.kind == kind }!.value
    }

    func testEndToEndMeasurements() {
        let s = scenario()
        let checker = PositionChecker(markerWidthMM: 100, markerHeightMM: 100)
        let result = checker.check(markerCornersPx: s.corners,
                                   landmarksPx: s.landmarks,
                                   heightCm: 185,
                                   frameWidth: 1000, frameHeight: 1000)

        guard case .success(let report) = result else {
            return XCTFail("expected success, got \(result)")
        }

        XCTAssertEqual(value(report, .reach), 700, accuracy: 0.01)
        XCTAssertEqual(value(report, .extensionHeight), 100, accuracy: 0.01)
        XCTAssertEqual(value(report, .armToTip), 200, accuracy: 0.01)
        XCTAssertEqual(value(report, .armrestAngle), 10, accuracy: 0.01)
        XCTAssertEqual(value(report, .saddleSetback), 80, accuracy: 0.01)

        // Height 185, setback 80 → Cat 2; everything inside limits → pass.
        XCTAssertEqual(report.category, .cat2)
        XCTAssertEqual(report.overallState, .pass)
        XCTAssertEqual(report.rulesVersion, UCIRules.current.rulesVersion)
    }

    func testSetbackOverrideDrivesCategoryAndValue() {
        let s = scenario()
        let checker = PositionChecker()
        // Override to a forward position; height becomes irrelevant.
        let result = checker.check(markerCornersPx: s.corners,
                                   landmarksPx: s.landmarks,
                                   heightCm: 185,
                                   setbackOverrideMm: 30,
                                   frameWidth: 1000, frameHeight: 1000)
        guard case .success(let report) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(report.category, .forward)
        XCTAssertEqual(value(report, .saddleSetback), 30, accuracy: 1e-9)
    }

    func testCaptureRejectionPropagates() {
        let s = scenario()
        // Tilt the marker badly.
        var corners = s.corners
        corners[1] = Point2(x: corners[1].x, y: corners[1].y - 40)
        let checker = PositionChecker()
        let result = checker.check(markerCornersPx: corners,
                                   landmarksPx: s.landmarks,
                                   heightCm: 185,
                                   frameWidth: 1000, frameHeight: 1000)
        guard case .failure(.capture) = result else {
            return XCTFail("expected capture failure, got \(result)")
        }
    }

    func testMissingLandmarksFails() {
        let s = scenario()
        var landmarks = s.landmarks
        landmarks[.saddleNose] = nil
        let checker = PositionChecker()
        let result = checker.check(markerCornersPx: s.corners,
                                   landmarksPx: landmarks,
                                   heightCm: 185,
                                   frameWidth: 1000, frameHeight: 1000)
        XCTAssertEqual(result, .failure(.missingLandmarks))
    }
}
