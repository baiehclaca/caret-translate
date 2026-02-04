import XCTest
@testable import CaretTranslate

final class SentenceSelectorTests: XCTestCase {
    func testSelectsSentenceAroundCaret() {
        let text = "Hello world. How are you?"
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "How"))
        let selector = SentenceSelector()

        let selection = selector.selectSentence(in: snapshot)

        XCTAssertEqual(selection?.sentence, "How are you?")
    }

    func testSelectsWholeTextWhenNoTerminators() {
        let text = "No punctuation here"
        let snapshot = TextSnapshot(text: text, caretUTF16: 5)
        let selector = SentenceSelector()

        let selection = selector.selectSentence(in: snapshot)

        XCTAssertEqual(selection?.sentence, "No punctuation here")
    }

    func testTreatsNewlineAsSentenceBoundary() {
        let text = "First line\nSecond line"
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "Second"))
        let selector = SentenceSelector()

        let selection = selector.selectSentence(in: snapshot)

        XCTAssertEqual(selection?.sentence, "Second line")
    }

    func testTrimsLeadingWhitespaceAfterTerminator() {
        let text = "First.   Second!"
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "Second"))
        let selector = SentenceSelector()

        let selection = selector.selectSentence(in: snapshot)

        XCTAssertEqual(selection?.sentence, "Second!")
    }
}

private func caretLocation(in text: String, substring: String) -> Int {
    let nsText = text as NSString
    let range = nsText.range(of: substring)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range.location + 1
}
