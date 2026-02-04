import XCTest
@testable import CaretTranslate

final class DoubleTapDetectorTests: XCTestCase {
    func testTriggersOnSecondTapWithinThreshold() {
        let detector = DoubleTapDetector(threshold: 0.3)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertTrue(detector.registerTap(at: 1.2))
    }

    func testDoesNotTriggerWhenOutsideThreshold() {
        let detector = DoubleTapDetector(threshold: 0.3)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertFalse(detector.registerTap(at: 1.4))
    }

    func testResetsAfterTrigger() {
        let detector = DoubleTapDetector(threshold: 0.3)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertTrue(detector.registerTap(at: 1.2))
        XCTAssertFalse(detector.registerTap(at: 1.25))
        XCTAssertTrue(detector.registerTap(at: 1.45))
    }
}
