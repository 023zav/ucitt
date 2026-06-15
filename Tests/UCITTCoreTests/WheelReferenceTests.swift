import XCTest
@testable import UCITTCore

final class WheelReferenceTests: XCTestCase {

    // Landmarks in world mm (x horizontal, y up), known answers below.
    private let mmLandmarks: [Landmark: Point2] = [
        .bb:         Point2(x: 100, y: 200),
        .tip:        Point2(x: 800, y: 500),
        .armMid:     Point2(x: 700, y: 600),
        .armLead:    Point2(x: 600, y: 550),
        .armRear:    Point2(x: 700, y: 550 + 100 * tan(10 * .pi / 180)),
        .saddleNose: Point2(x: 20,  y: 180)
    ]
    private let wheelDiameter = 672.0   // radius 336 mm

    /// Project a world-mm point to pixels given scale, rotation and rear-hub origin.
    private func project(_ mm: Point2, scalePxPerMM: Double, rotation: Double,
                         rearHubPx: Point2) -> Point2 {
        // world x along uHat, world y (up) along vHat = uHat rotated to point up.
        let u = Point2(x: cos(rotation), y: sin(rotation))
        // up in image is the perpendicular with negative y
        var v = Point2(x: -u.y, y: u.x)
        if v.y > 0 { v = Point2(x: u.y, y: -u.x) }
        return Point2(x: rearHubPx.x + (mm.x * u.x + mm.y * v.x) * scalePxPerMM,
                      y: rearHubPx.y + (mm.x * u.y + mm.y * v.y) * scalePxPerMM)
    }

    private func value(_ ms: [UCITTCore.Measurement], _ k: MeasurementKind) -> Double {
        ms.first { $0.kind == k }!.value
    }

    private func runScenario(rotation: Double) {
        let scale = 2.0                  // px per mm
        let rearHub = Point2(x: 400, y: 600)
        // Build the wheel reference pixels consistent with scale/rotation.
        let u = Point2(x: cos(rotation), y: sin(rotation))
        var v = Point2(x: -u.y, y: u.x)
        if v.y > 0 { v = Point2(x: u.y, y: -u.x) }
        let frontHub = Point2(x: rearHub.x + u.x * 1000, y: rearHub.y + u.y * 1000)
        let radiusPx = (wheelDiameter / 2) * scale
        // ground contact is straight down from the hub (opposite to "up" v).
        let ground = Point2(x: rearHub.x - v.x * radiusPx, y: rearHub.y - v.y * radiusPx)

        var px: [Landmark: Point2] = [:]
        for (lm, mm) in mmLandmarks {
            px[lm] = project(mm, scalePxPerMM: scale, rotation: rotation, rearHubPx: rearHub)
        }

        let checker = PositionChecker()
        let result = checker.check(landmarksPx: px,
                                   rearHubPx: rearHub, frontHubPx: frontHub,
                                   groundContactPx: ground,
                                   wheelDiameterMM: wheelDiameter,
                                   heightCm: 185)
        guard case .success(let report) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(value(report.rawValues, .reach), 700, accuracy: 0.05)
        XCTAssertEqual(value(report.rawValues, .extensionHeight), 100, accuracy: 0.05)
        XCTAssertEqual(value(report.rawValues, .armToTip), 200, accuracy: 0.05)
        XCTAssertEqual(value(report.rawValues, .armrestAngle), 10, accuracy: 0.05)
        XCTAssertEqual(value(report.rawValues, .saddleSetback), 80, accuracy: 0.05)
        XCTAssertEqual(report.category, .cat2)
    }

    func testWheelScaleSquareOn() { runScenario(rotation: 0) }

    /// A photo taken slightly tilted: the hub line defines horizontal, so the
    /// result must be unchanged.
    func testWheelScaleTiltedPhoto() { runScenario(rotation: 8 * .pi / 180) }

    func testDegenerateReturnsNil() {
        XCTAssertNil(WheelRectifier(rearHub: Point2(x: 0, y: 0),
                                    frontHub: Point2(x: 0, y: 0),
                                    groundContact: Point2(x: 0, y: 50),
                                    wheelDiameterMM: 672))
    }
}

private extension ResultReport {
    /// Convenience: evaluated measurements as raw kind/value for assertions.
    var rawValues: [UCITTCore.Measurement] {
        measurements.map { UCITTCore.Measurement(kind: $0.kind, value: $0.value) }
    }
}
