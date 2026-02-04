import XCTest
@testable import CaretTranslate

final class RoutingTranslatorTests: XCTestCase {

    func testRoutesToAppleForSupportedLanguages() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // English to Japanese - Apple supported
        let result = try await router.translate("Hello", from: Language(code: "en"), to: Language(code: "ja"))
        XCTAssertEqual(result, "Apple result")
        XCTAssertEqual(appleTranslator.callCount, 1)
        XCTAssertEqual(nllbTranslator.callCount, 0)
    }

    func testRoutesToNLLBForUnsupportedLanguages() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // English to Swedish - NLLB only
        let result = try await router.translate("Hello", from: Language(code: "en"), to: Language(code: "sv"))
        XCTAssertEqual(result, "NLLB result")
        XCTAssertEqual(appleTranslator.callCount, 0)
        XCTAssertEqual(nllbTranslator.callCount, 1)
    }

    func testRoutesToNLLBWhenSourceIsUnsupported() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // Swedish to English - NLLB (source not Apple supported)
        let result = try await router.translate("Hej", from: Language(code: "sv"), to: Language(code: "en"))
        XCTAssertEqual(result, "NLLB result")
        XCTAssertEqual(appleTranslator.callCount, 0)
        XCTAssertEqual(nllbTranslator.callCount, 1)
    }

    func testRoutesAutoToNLLBWhenDetectedLanguageIsNLLBOnly() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")
        let identifier = MockLanguageIdentifier(dominant: Language(code: "fil"))

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator,
            languageIdentifier: identifier
        )

        let result = try await router.translate("ako sa mas?", from: .auto, to: Language(code: "en"))
        XCTAssertEqual(result, "NLLB result")
        XCTAssertEqual(appleTranslator.callCount, 0)
        XCTAssertEqual(nllbTranslator.callCount, 1)
        XCTAssertEqual(nllbTranslator.lastFrom?.code, "fil")
    }
}

private final class MockTranslator: Translator, @unchecked Sendable {
    let result: String?
    var callCount = 0
    var lastFrom: Language?

    init(result: String?) {
        self.result = result
    }

    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        callCount += 1
        lastFrom = from
        return result
    }
}

private final class MockLanguageIdentifier: WordLanguageIdentifying, @unchecked Sendable {
    private let dominant: Language?

    init(dominant: Language?) {
        self.dominant = dominant
    }

    func dominantLanguage(for text: String) -> Language? {
        dominant
    }

    func language(for text: String, wordRangeUTF16: NSRange) -> Language? {
        nil
    }
}
