import XCTest
@testable import CaretTranslate

final class ContextualFixerContextTests: XCTestCase {
    func testBuildsTaggedSourceSentence() {
        let sentence = "how can i express by this?"
        let range = wordRange(in: sentence, substring: "express")
        let context = ContextualFixerContext(
            sourceSentence: sentence,
            sourceWordRangeUTF16: range,
            translatedSentence: "how can i expressed by this?",
            sourceLanguage: Language(code: "sk"),
            targetLanguage: Language(code: "en")
        )

        XCTAssertEqual(context.taggedSourceSentence(), "how can i <source>express</source> by this?")
    }

    func testReturnsNilWhenRangeIsInvalid() {
        let sentence = "short"
        let context = ContextualFixerContext(
            sourceSentence: sentence,
            sourceWordRangeUTF16: NSRange(location: 10, length: 3),
            translatedSentence: "short",
            sourceLanguage: Language(code: "sk"),
            targetLanguage: Language(code: "en")
        )

        XCTAssertNil(context.taggedSourceSentence())
    }
}

private func wordRange(in text: String, substring: String) -> NSRange {
    let nsText = text as NSString
    let range = nsText.range(of: substring)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range
}
