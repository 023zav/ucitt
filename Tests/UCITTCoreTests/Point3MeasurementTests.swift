import XCTest
@testable import UCITTCore

final class Point3MeasurementTests: XCTestCase {

    private func scenario() -> [Landmark: Point3] {
        // Gravity-aligned mm, side-on (z == 0): x forward, y up.
        [
            .bb:         Point3(x: 100, y: 200, z: 0),
            .tip:        Point3(x: 800, y: 500, z: 0),
            .armMid:     Point3(x: 700, y: 600, z: 0),
            .armLead:    Point3(x: 600, y: 550, z: 0),
            .armRear:    Point3(x: 700, y: 550 + 100 * tan(10 * .pi / 180), z: 0),
            .saddleNose: Point3(x: 20,  y: 520, z: 0)
        ]
    }

    private func value(_ ms: [UCITTCore.Measurement], _ k: MeasurementKind) -> Double {
        ms.first { $0.kind == k }!.value
    }

    func testMeasurementsMatch2DFormulas() {
        let ms = UCITTCore.Measurement.all(points3: scenario())!
        XCTAssertEqual(value(ms, .reach), 700, accuracy: 1e-6)
        XCTAssertEqual(value(ms, .extensionHeight), 100, accuracy: 1e-6)
        XCTAssertEqual(value(ms, .armToTip), 200, accuracy: 1e-6)
        XCTAssertEqual(value(ms, .armrestAngle), 10, accuracy: 1e-6)
        XCTAssertEqual(value(ms, .saddleSetback), 80, accuracy: 1e-6)
    }

    func testHorizontalUsesGroundPlaneAndVerticalIgnoresIt() {
        let a = Point3(x: 0, y: 1000, z: 0)
        let b = Point3(x: 30, y: 50, z: 40)            // dx=30, dz=40 -> 50 horizontal
        XCTAssertEqual(a.horizontalDistance(to: b), 50, accuracy: 1e-9)
        XCTAssertEqual(a.verticalDistance(to: b), 950, accuracy: 1e-9)
    }

    func testEndToEndARKitReportIsCat2Pass() {
        let checker = PositionChecker()  // marker dims irrelevant for the 3D path
        let result = checker.check(points3: scenario(), heightCm: 185)
        guard case .success(let report) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(report.category, .cat2)
        XCTAssertEqual(report.overallState, .pass)
    }

    func testMissingPointFails() {
        var pts = scenario()
        pts[.tip] = nil
        XCTAssertNil(UCITTCore.Measurement.all(points3: pts))
    }
}
