import XCTest
@testable import UCITTCore

final class RulesTests: XCTestCase {

    // MARK: Category logic (§7)

    func testForwardWhenSetbackBelowThreshold() {
        let d = CategoryEngine.decide(heightCm: 195, saddleSetbackMm: 49.9)
        XCTAssertEqual(d.category, .forward) // setback wins regardless of height
    }

    func testSetbackThresholdIsExclusive() {
        // Exactly 50mm is NOT < 50, so it is not Forward.
        let d = CategoryEngine.decide(heightCm: 170, saddleSetbackMm: 50)
        XCTAssertEqual(d.category, .cat1)
    }

    func testCat1Below180() {
        let d = CategoryEngine.decide(heightCm: 179.9, saddleSetbackMm: 60)
        XCTAssertEqual(d.category, .cat1)
    }

    func testCat2Boundaries() {
        XCTAssertEqual(CategoryEngine.decide(heightCm: 180, saddleSetbackMm: 60).category, .cat2)
        XCTAssertEqual(CategoryEngine.decide(heightCm: 189.9, saddleSetbackMm: 60).category, .cat2)
    }

    func testCat3AtAndAbove190() {
        XCTAssertEqual(CategoryEngine.decide(heightCm: 190, saddleSetbackMm: 60).category, .cat3)
        XCTAssertEqual(CategoryEngine.decide(heightCm: 201, saddleSetbackMm: 60).category, .cat3)
    }

    func testStickerFlagAppearsForTallRiders() {
        let tall = CategoryEngine.decide(heightCm: 185, saddleSetbackMm: 60)
        XCTAssertTrue(tall.flags.contains { $0.contains("frame sticker") })
        let short = CategoryEngine.decide(heightCm: 170, saddleSetbackMm: 60)
        XCTAssertFalse(short.flags.contains { $0.contains("frame sticker") })
    }

    // MARK: Evaluator (§7)

    func testReachPassBorderlineFail() {
        let rules = UCIRules.current
        // Cat 1 reach max 800.
        let pass = Evaluator.evaluate(measurements: [Measurement(kind: .reach, value: 750)],
                                      category: .cat1, rules: rules)[0]
        XCTAssertEqual(pass.state, .pass)
        XCTAssertEqual(pass.margin, 50, accuracy: 1e-9)

        let borderline = Evaluator.evaluate(measurements: [Measurement(kind: .reach, value: 795)],
                                            category: .cat1, rules: rules)[0]
        XCTAssertEqual(borderline.state, .borderline) // 5mm under, within 10mm band

        let fail = Evaluator.evaluate(measurements: [Measurement(kind: .reach, value: 810)],
                                      category: .cat1, rules: rules)[0]
        XCTAssertEqual(fail.state, .fail)
        XCTAssertEqual(fail.margin, -10, accuracy: 1e-9)
    }

    func testArmToTipMinimumDirection() {
        let rules = UCIRules.current // min 180
        let under = Evaluator.evaluate(measurements: [Measurement(kind: .armToTip, value: 170)],
                                       category: .cat1, rules: rules)[0]
        XCTAssertEqual(under.direction, .min)
        XCTAssertEqual(under.state, .fail)
        XCTAssertEqual(under.margin, -10, accuracy: 1e-9)

        let ok = Evaluator.evaluate(measurements: [Measurement(kind: .armToTip, value: 200)],
                                    category: .cat1, rules: rules)[0]
        XCTAssertEqual(ok.state, .pass)
    }

    func testAngleUsesDegreeBand() {
        let rules = UCIRules.current // max 30°, band 2°
        let borderline = Evaluator.evaluate(measurements: [Measurement(kind: .armrestAngle, value: 29)],
                                            category: .cat1, rules: rules)[0]
        XCTAssertEqual(borderline.state, .borderline)
        let fail = Evaluator.evaluate(measurements: [Measurement(kind: .armrestAngle, value: 31)],
                                      category: .cat1, rules: rules)[0]
        XCTAssertEqual(fail.state, .fail)
    }

    func testSaddleSetbackIsInformationalOnly() {
        let m = Evaluator.evaluate(measurements: [Measurement(kind: .saddleSetback, value: 65)],
                                   category: .cat2)[0]
        XCTAssertEqual(m.value, 65, accuracy: 1e-9)
        XCTAssertTrue(m.limit.isNaN)
    }
}
