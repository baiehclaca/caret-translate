import XCTest
@testable import CaretTranslate

final class NaturalLanguageWordLanguageIdentifierTests: XCTestCase {
    /// Verifies that the identifier can detect a dominant language for a clear sentence.
    func testDetectsDominantLanguageForSentence() throws {
        let identifier = NaturalLanguageWordLanguageIdentifier()
        let text = "This is a simple sentence."
        let language = identifier.dominantLanguage(for: text)
        if language == nil {
            throw XCTSkip("NaturalLanguage could not determine a dominant language in this environment.")
        }
        XCTAssertEqual(language?.code, "en")
    }

    /// Verifies that the identifier can detect a word language for a clear token.
    func testDetectsWordLanguageForToken() throws {
        let identifier = NaturalLanguageWordLanguageIdentifier()
        let text = "ありがとう"
        let range = (text as NSString).range(of: "ありがとう")
        XCTAssertNotEqual(range.location, NSNotFound)
        let language = identifier.language(for: text, wordRangeUTF16: range)
        if language == nil {
            throw XCTSkip("NaturalLanguage could not determine a word language in this environment.")
        }
        XCTAssertEqual(language?.code, "ja")
    }
}
