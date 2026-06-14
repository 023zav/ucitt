import XCTest
@testable import UCITTCore

final class GeometryTests: XCTestCase {

    func testDistance() {
        let a = Point2(x: 0, y: 0)
        let b = Point2(x: 3, y: 4)
        XCTAssertEqual(Geometry.distance(a, b), 5, accuracy: 1e-9)
    }

    func testHorizontalAndVerticalSigned() {
        let a = Point2(x: 10, y: 2)
        let b = Point2(x: 4, y: 9)
        XCTAssertEqual(Geometry.horizontal(a, b), 6, accuracy: 1e-9)
        XCTAssertEqual(Geometry.vertical(a, b), -7, accuracy: 1e-9)
    }

    func testInclinationIsDirectionAgnostic() {
        let lead = Point2(x: 0, y: 0)
        // Rear sits behind (negative x) and 10° higher.
        let dx = -100.0
        let dy = -100.0 * tan(10 * .pi / 180)
        let rear = Point2(x: dx, y: dy)
        let incl = Geometry.inclinationDegrees(lead, rear)
        XCTAssertEqual(incl, 10, accuracy: 1e-6)
        // Same segment, reversed, gives the same inclination.
        XCTAssertEqual(Geometry.inclinationDegrees(rear, lead), 10, accuracy: 1e-6)
    }

    func testInclinationHorizontalAndVertical() {
        XCTAssertEqual(Geometry.inclinationDegrees(Point2(x: 0, y: 5),
                                                   Point2(x: 9, y: 5)), 0, accuracy: 1e-9)
        XCTAssertEqual(Geometry.inclinationDegrees(Point2(x: 1, y: 0),
                                                   Point2(x: 1, y: 8)), 90, accuracy: 1e-9)
    }
}
