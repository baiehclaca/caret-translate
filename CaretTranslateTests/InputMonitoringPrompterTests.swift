import XCTest
@testable import CaretTranslate

final class InputMonitoringPrompterTests: XCTestCase {
    func testReturnsTrueWhenAlreadyGranted() {
        let checker = StubChecker(access: kIOHIDAccessTypeGranted, requestResult: false)
        let prompter = InputMonitoringPrompter(checker: checker)

        XCTAssertTrue(prompter.ensureAccess())
        XCTAssertEqual(checker.requestCount, 0)
    }

    func testReturnsRequestResultWhenDenied() {
        let checker = StubChecker(access: kIOHIDAccessTypeDenied, requestResult: true)
        let prompter = InputMonitoringPrompter(checker: checker)

        XCTAssertTrue(prompter.ensureAccess())
        XCTAssertEqual(checker.requestCount, 1)
    }

    func testReturnsRequestResultWhenUnknown() {
        let checker = StubChecker(access: kIOHIDAccessTypeUnknown, requestResult: false)
        let prompter = InputMonitoringPrompter(checker: checker)

        XCTAssertFalse(prompter.ensureAccess())
        XCTAssertEqual(checker.requestCount, 1)
    }
}

private final class StubChecker: InputMonitoringChecking {
    private(set) var requestCount = 0
    private let access: IOHIDAccessType
    private let requestResult: Bool

    init(access: IOHIDAccessType, requestResult: Bool) {
        self.access = access
        self.requestResult = requestResult
    }

    func check() -> IOHIDAccessType {
        access
    }

    func request() -> Bool {
        requestCount += 1
        return requestResult
    }
}
