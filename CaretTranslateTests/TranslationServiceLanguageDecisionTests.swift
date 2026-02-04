import XCTest
@testable import CaretTranslate

final class TranslationServiceLanguageDecisionTests: XCTestCase {
    /// Uses word translation for foreign words when the sentence is target-dominant.
    func testTranslatesForeignWordsWhenSentenceMatchesTarget() async throws {
        let sentenceTranslator = RecordingTranslator(result: "SENTENCE")
        let wordTranslator = MapTranslator(map: [
            "hola": "hello",
            "bonjour": "hello"
        ])
        let identifier = StubLanguageIdentifier(
            dominant: Language(code: "en"),
            wordMap: [
                "hello": Language(code: "en"),
                "hola": Language(code: "es"),
                "bonjour": Language(code: "fr")
            ]
        )
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: nil,
            languageIdentifier: identifier,
            decisionLogger: nil
        )

        let text = "Hello hola bonjour."
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "hola"))

        let replacement = try await service.replacement(for: snapshot, from: .auto, to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "Hello hello hello.")
        XCTAssertEqual(replacement?.applying(to: text), "Hello hello hello.")
        XCTAssertTrue(sentenceTranslator.inputs.isEmpty)
        XCTAssertEqual(wordTranslator.inputs, ["hola", "bonjour"])
    }

    /// Uses sentence translation when the sentence language is not the target language.
    func testUsesSentenceTranslationWhenSentenceNotTarget() async throws {
        let sentenceTranslator = RecordingTranslator(result: "SENTENCE")
        let wordTranslator = MapTranslator(map: ["hola": "hello"])
        let identifier = StubLanguageIdentifier(
            dominant: Language(code: "es"),
            wordMap: [
                "hola": Language(code: "es"),
                "mundo": Language(code: "es")
            ]
        )
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: nil,
            languageIdentifier: identifier,
            decisionLogger: nil
        )

        let text = "Hola mundo."
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "Hola"))

        let replacement = try await service.replacement(for: snapshot, from: .auto, to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "SENTENCE")
        XCTAssertEqual(replacement?.applying(to: text), "SENTENCE")
        XCTAssertEqual(sentenceTranslator.inputs, ["Hola mundo."])
        XCTAssertTrue(wordTranslator.inputs.isEmpty)
    }

    /// Still translates foreign words when the sentence is target-dominant and source is explicit.
    func testTranslatesForeignWordsWhenSourceExplicit() async throws {
        let sentenceTranslator = RecordingTranslator(result: "SENTENCE")
        let wordTranslator = MapTranslator(map: ["hola": "hello"])
        let identifier = StubLanguageIdentifier(
            dominant: Language(code: "en"),
            wordMap: [
                "hello": Language(code: "en"),
                "hola": Language(code: "es")
            ]
        )
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: nil,
            languageIdentifier: identifier,
            decisionLogger: nil
        )

        let text = "Hello hola."
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "hola"))

        let replacement = try await service.replacement(for: snapshot, from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "Hello hello.")
        XCTAssertEqual(replacement?.applying(to: text), "Hello hello.")
        XCTAssertTrue(sentenceTranslator.inputs.isEmpty)
        XCTAssertEqual(wordTranslator.inputs, ["hola"])
    }
}

private final class RecordingTranslator: Translator, @unchecked Sendable {
    private(set) var inputs: [String] = []
    private let result: String?

    /// Creates a translator that records inputs and returns a fixed result.
    init(result: String?) {
        self.result = result
    }

    /// Records the translated text and returns the configured result.
    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        inputs.append(text)
        return result
    }
}

private final class MapTranslator: Translator, @unchecked Sendable {
    private(set) var inputs: [String] = []
    private let map: [String: String]

    /// Creates a translator that maps exact inputs to outputs.
    init(map: [String: String]) {
        self.map = map
    }

    /// Records each input and returns the mapped output if available.
    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        inputs.append(text)
        return map[text.lowercased()]
    }
}

private struct StubLanguageIdentifier: WordLanguageIdentifying {
    let dominant: Language?
    let wordMap: [String: Language]

    /// Returns the preset dominant language for sentence detection.
    func dominantLanguage(for text: String) -> Language? {
        dominant
    }

    /// Returns the preset word language for the provided range.
    func language(for text: String, wordRangeUTF16: NSRange) -> Language? {
        let nsText = text as NSString
        guard wordRangeUTF16.location != NSNotFound,
              wordRangeUTF16.location + wordRangeUTF16.length <= nsText.length else {
            return nil
        }
        let token = nsText.substring(with: wordRangeUTF16).lowercased()
        return wordMap[token]
    }
}

/// Returns a caret location inside the requested substring.
private func caretLocation(in text: String, substring: String) -> Int {
    let nsText = text as NSString
    let range = nsText.range(of: substring)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range.location + 1
}
