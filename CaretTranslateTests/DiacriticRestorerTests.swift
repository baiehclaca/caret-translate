import XCTest
@testable import CaretTranslate

final class DiacriticRestorerTests: XCTestCase {

    /// Ensures Slovak phrase restoration adds missing diacritics.
    func testRestoresSlovakGreeting() {
        let restorer = DiacriticRestorer()
        let restored = restorer.restore("ako sa mas", language: Language(code: "sk"))
        XCTAssertEqual(restored, "ako sa máš")
    }

    /// Ensures Czech phrase restoration adds missing diacritics.
    func testRestoresCzechGreeting() {
        let restorer = DiacriticRestorer()
        let restored = restorer.restore("jak se mas?", language: Language(code: "cs"))
        XCTAssertEqual(restored, "jak se máš?")
    }

    /// Ensures diacritic restoration skips already-correct text.
    func testSkipsWhenDiacriticsPresent() {
        let restorer = DiacriticRestorer()
        let restored = restorer.restore("ako sa máš", language: Language(code: "sk"))
        XCTAssertNil(restored)
    }

    /// Ensures unsupported languages do not trigger restoration.
    func testSkipsUnsupportedLanguage() {
        let restorer = DiacriticRestorer()
        let restored = restorer.restore("how are you", language: Language(code: "en"))
        XCTAssertNil(restored)
    }
}
