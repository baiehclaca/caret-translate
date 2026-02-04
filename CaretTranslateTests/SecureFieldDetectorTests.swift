import XCTest
@testable import CaretTranslate

final class SecureFieldDetectorTests: XCTestCase {
    func testDetectsSecureBySubrole() {
        XCTAssertTrue(SecureFieldDetector.isSecure(role: "AXTextField", subrole: "AXSecureTextField"))
    }

    func testDetectsSecureByRole() {
        XCTAssertTrue(SecureFieldDetector.isSecure(role: "AXSecureTextField", subrole: nil))
    }

    func testReturnsFalseForNormalField() {
        XCTAssertFalse(SecureFieldDetector.isSecure(role: "AXTextField", subrole: "AXStandardWindow"))
    }
}
