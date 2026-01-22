import XCTest
@testable import CaretTranslateCore

final class TranslationServiceTests: XCTestCase {
    func testReplacesSentenceWhenTranslationAvailable() async throws {
        let sentenceTranslator = StubTranslator(result: "How are you doing?")
        let wordTranslator = StubTranslator(result: "place")
        let fixer = StubFixer(result: nil)
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: fixer
        )

        let text = "Hello world. How are you?"
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "How"))

        let replacement = try await service.replacement(for: snapshot, from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "How are you doing?")
        XCTAssertEqual(replacement?.applying(to: text), "Hello world. How are you doing?")
        XCTAssertEqual(sentenceTranslator.inputs, ["How are you?"])
        XCTAssertTrue(wordTranslator.inputs.isEmpty)
        XCTAssertEqual(fixer.contexts.count, 1)
    }

    func testFallsBackToWordTranslationWhenSentenceTranslationUnavailable() async throws {
        let sentenceTranslator = StubTranslator(result: nil)
        let wordTranslator = StubTranslator(result: "place")
        let fixer = StubFixer(result: "unused")
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: fixer
        )

        let text = "to vyplnit miesto"
        let snapshot = TextSnapshot(text: text, caretUTF16: text.utf16.count)

        let replacement = try await service.replacement(for: snapshot, from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "place")
        XCTAssertEqual(replacement?.applying(to: text), "to vyplnit place")
        XCTAssertEqual(sentenceTranslator.inputs, [text])
        XCTAssertEqual(wordTranslator.inputs, ["miesto"])
        XCTAssertTrue(fixer.contexts.isEmpty)
    }

    func testAppliesContextualFixerWhenAvailable() async throws {
        let sentenceTranslator = StubTranslator(result: "how can i expressed by this?")
        let wordTranslator = StubTranslator(result: "unused")
        let fixer = StubFixer(result: "how can i express by this?")
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: fixer
        )

        let text = "how can i express by this?"
        let snapshot = TextSnapshot(text: text, caretUTF16: caretLocation(in: text, substring: "express"))

        let replacement = try await service.replacement(for: snapshot, from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(replacement?.replacement, "how can i express by this?")
        XCTAssertEqual(sentenceTranslator.inputs, [text])
        XCTAssertTrue(wordTranslator.inputs.isEmpty)
        XCTAssertEqual(fixer.contexts.first?.sourceSentence, text)
        XCTAssertEqual(fixer.contexts.first?.translatedSentence, "how can i expressed by this?")
        XCTAssertEqual(fixer.contexts.first?.sourceWordRangeUTF16, wordRange(in: text, substring: "express"))
    }
}

private final class StubTranslator: Translator {
    var inputs: [String] = []
    let result: String?

    init(result: String?) {
        self.result = result
    }

    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        inputs.append(text)
        return result
    }
}

private final class StubFixer: ContextualFixer {
    var contexts: [ContextualFixerContext] = []
    let result: String?

    init(result: String?) {
        self.result = result
    }

    func fix(_ context: ContextualFixerContext) async throws -> String? {
        contexts.append(context)
        return result
    }
}

private func caretLocation(in text: String, substring: String) -> Int {
    let nsText = text as NSString
    let range = nsText.range(of: substring)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range.location + 1
}

private func wordRange(in text: String, substring: String) -> NSRange {
    let nsText = text as NSString
    let range = nsText.range(of: substring)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range
}
