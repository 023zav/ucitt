import XCTest
@testable import UCITTCore

final class MarkerGeometryTests: XCTestCase {

    private func square(at o: Point2, size: Double) -> [Point2] {
        [Point2(x: o.x, y: o.y),
         Point2(x: o.x + size, y: o.y),
         Point2(x: o.x + size, y: o.y + size),
         Point2(x: o.x, y: o.y + size)]
    }

    func testLevelSquarePasses() {
        let corners = square(at: Point2(x: 100, y: 100), size: 200)
        XCTAssertNil(MarkerGeometry.validate(corners: corners,
                                             frameWidth: 1000, frameHeight: 1000))
        XCTAssertEqual(MarkerGeometry.tiltDegrees(corners: corners), 0, accuracy: 1e-9)
        XCTAssertEqual(MarkerGeometry.perspectiveSkew(corners: corners), 0, accuracy: 1e-9)
    }

    func testTiltedMarkerRejected() {
        // Rotate the square's top edge ~3° by lifting TR.
        var corners = square(at: Point2(x: 100, y: 100), size: 200)
        corners[1] = Point2(x: 300, y: 100 - 200 * tan(3 * .pi / 180))
        let r = MarkerGeometry.validate(corners: corners, frameWidth: 1000, frameHeight: 1000)
        guard case .notLevel = r else { return XCTFail("expected notLevel, got \(String(describing: r))") }
    }

    func testTooSmallRejected() {
        let corners = square(at: Point2(x: 10, y: 10), size: 50) // 50/1000 = 5% coverage
        let r = MarkerGeometry.validate(corners: corners, frameWidth: 1000, frameHeight: 1000)
        guard case .tooSmall = r else { return XCTFail("expected tooSmall, got \(String(describing: r))") }
    }

    func testPerspectiveRejected() {
        // Strong trapezoid: top half as wide as bottom.
        let corners = [
            Point2(x: 150, y: 100), Point2(x: 250, y: 100),
            Point2(x: 350, y: 300), Point2(x:  50, y: 300)
        ]
        let r = MarkerGeometry.validate(corners: corners, frameWidth: 1000, frameHeight: 1000)
        guard case .tooMuchPerspective = r else {
            return XCTFail("expected tooMuchPerspective, got \(String(describing: r))")
        }
    }

    func testWrongCornerCount() {
        let r = MarkerGeometry.validate(corners: [Point2(x: 0, y: 0)],
                                        frameWidth: 1000, frameHeight: 1000)
        XCTAssertEqual(r, .wrongCornerCount(1))
    }
}
