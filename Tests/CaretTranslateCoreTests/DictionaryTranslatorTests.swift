import XCTest
@testable import CaretTranslateCore

final class DictionaryTranslatorTests: XCTestCase {
    func testTranslatesLowercaseWord() async throws {
        let translator = DictionaryTranslator(entries: [
            LanguagePair(from: Language(code: "sk"), to: Language(code: "en")): [
                "vyplnit": "fill",
                "miesto": "place"
            ]
        ])

        let result = try await translator.translate("vyplnit", from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(result, "fill")
    }

    func testPreservesCapitalization() async throws {
        let translator = DictionaryTranslator(entries: [
            LanguagePair(from: Language(code: "sk"), to: Language(code: "en")): [
                "miesto": "place"
            ]
        ])

        let titleCase = try await translator.translate("Miesto", from: Language(code: "sk"), to: Language(code: "en"))
        let uppercased = try await translator.translate("MIESTO", from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(titleCase, "Place")
        XCTAssertEqual(uppercased, "PLACE")
    }

    func testReturnsNilWhenMissing() async throws {
        let translator = DictionaryTranslator(entries: [
            LanguagePair(from: Language(code: "sk"), to: Language(code: "en")): [
                "miesto": "place"
            ]
        ])

        let result = try await translator.translate("unknown", from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertNil(result)
    }

    func testLoadsFromResource() async throws {
        let translator = try DictionaryTranslator(resourceName: "dictionary")

        let result = try await translator.translate("vyplnit", from: Language(code: "sk"), to: Language(code: "en"))

        XCTAssertEqual(result, "fill")
    }
}
