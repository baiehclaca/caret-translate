import XCTest
@testable import CaretTranslate

final class ContextTextReaderTests: XCTestCase {
    func testContextRangeCentersCaretWhenPossible() {
        let range = ContextTextReader.contextRange(caretUTF16: 50, length: 40, totalLength: 100)

        XCTAssertEqual(range.location, 30)
        XCTAssertEqual(range.length, 40)
    }

    func testContextRangeShiftsToStayWithinTotalLength() {
        let range = ContextTextReader.contextRange(caretUTF16: 95, length: 40, totalLength: 100)

        XCTAssertEqual(range.location, 60)
        XCTAssertEqual(range.length, 40)
    }

    func testContextRangeClampsWhenShorterThanRequested() {
        let range = ContextTextReader.contextRange(caretUTF16: 10, length: 50, totalLength: 30)

        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 30)
    }

    func testReadReturnsFirstSuccessfulRangeAndLocalCaret() {
        let reader = ContextTextReader(rangeSizes: [40, 20, 10])

        let result = reader.read(caretUTF16: 25, totalLength: 100) { range in
            guard range.length == 20 else {
                return nil
            }
            return "12345678901234567890"
        }

        XCTAssertEqual(result?.rangeUTF16.length, 20)
        XCTAssertEqual(result?.text, "12345678901234567890")
        XCTAssertEqual(result?.caretUTF16, 25 - result!.rangeUTF16.location)
    }
}
