import XCTest
@testable import CaretTranslateCore

final class WordSelectorTests: XCTestCase {
    func testSelectsLastWordWhenCaretJustAfterWord() {
        let text = "i think it should go a bit bigger to vyplnit miesto"
        let snapshot = TextSnapshot(text: text, caretUTF16: text.utf16.count)
        let selector = WordSelector(maxDistance: 1)

        let selection = selector.selectNearestWord(in: snapshot)

        XCTAssertEqual(selection?.word, "miesto")
    }

    func testSelectsWordWhenCaretInsideWord() {
        let text = "make it vyplnit now"
        let caret = (text as NSString).range(of: "vyplnit").location + 3
        let snapshot = TextSnapshot(text: text, caretUTF16: caret)
        let selector = WordSelector(maxDistance: 1)

        let selection = selector.selectNearestWord(in: snapshot)

        XCTAssertEqual(selection?.word, "vyplnit")
    }

    func testReturnsNilWhenNoWordNearby() {
        let snapshot = TextSnapshot(text: "   ", caretUTF16: 1)
        let selector = WordSelector(maxDistance: 0)

        let selection = selector.selectNearestWord(in: snapshot)

        XCTAssertNil(selection)
    }

    func testPrefersLeftWordWhenEquidistant() {
        let text = "left right"
        let caret = (text as NSString).range(of: " ").location
        let snapshot = TextSnapshot(text: text, caretUTF16: caret)
        let selector = WordSelector(maxDistance: 1)

        let selection = selector.selectNearestWord(in: snapshot)

        XCTAssertEqual(selection?.word, "left")
    }
}
