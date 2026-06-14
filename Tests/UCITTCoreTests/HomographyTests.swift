import XCTest
@testable import UCITTCore

final class HomographyTests: XCTestCase {

    /// A pure scale+translation pixel→mm mapping should be recovered exactly.
    func testScaleTranslationRecovery() {
        // Marker 100mm, imaged at 2 px/mm with a (50,50) px offset.
        let scale = 2.0
        let off = Point2(x: 50, y: 50)
        let mm = Homography.markerCornersMM(width: 100, height: 100)
        let px = mm.map { Point2(x: $0.x * scale + off.x, y: $0.y * scale + off.y) }

        let h = Homography.estimate(src: px, dst: mm)
        XCTAssertNotNil(h)

        // Corners map back to mm.
        for (p, m) in zip(px, mm) {
            let out = h!.apply(p)
            XCTAssertEqual(out.x, m.x, accuracy: 1e-6)
            XCTAssertEqual(out.y, m.y, accuracy: 1e-6)
        }

        // An interior pixel maps to the expected mm.
        let interiorMM = Point2(x: 37, y: 81)
        let interiorPx = Point2(x: interiorMM.x * scale + off.x,
                                y: interiorMM.y * scale + off.y)
        let out = h!.apply(interiorPx)
        XCTAssertEqual(out.x, interiorMM.x, accuracy: 1e-6)
        XCTAssertEqual(out.y, interiorMM.y, accuracy: 1e-6)
    }

    /// A genuine perspective quad (trapezoid) should still rectify to the square.
    func testPerspectiveRecovery() {
        let mm = Homography.markerCornersMM(width: 100, height: 100)
        // Trapezoid: top edge narrower than bottom (perspective foreshortening).
        let px = [
            Point2(x: 120, y: 100),  // TL
            Point2(x: 280, y: 100),  // TR
            Point2(x: 320, y: 300),  // BR
            Point2(x:  80, y: 300)   // BL
        ]
        let h = Homography.estimate(src: px, dst: mm)
        XCTAssertNotNil(h)
        for (p, m) in zip(px, mm) {
            let out = h!.apply(p)
            XCTAssertEqual(out.x, m.x, accuracy: 1e-6)
            XCTAssertEqual(out.y, m.y, accuracy: 1e-6)
        }
    }

    /// Collinear source points are degenerate and must not yield a homography.
    func testDegenerateReturnsNil() {
        let mm = Homography.markerCornersMM(width: 100, height: 100)
        let collinear = [
            Point2(x: 0, y: 0),
            Point2(x: 1, y: 0),
            Point2(x: 2, y: 0),
            Point2(x: 3, y: 0)
        ]
        XCTAssertNil(Homography.estimate(src: collinear, dst: mm))
    }
}
