import XCTest
@testable import CaretTranslate

final class NLLBTranslatorTests: XCTestCase {

    func testTranslatorConformsToProtocol() {
        // Verify NLLBTranslator can be used as a Translator
        let translator: Translator = NLLBTranslator()
        XCTAssertNotNil(translator)
    }

    func testLanguageCodeMapping() {
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "sv"), "swe_Latn")
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "fi"), "fin_Latn")
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "unknown"), nil)
    }

    func testIsNLLBLanguage() {
        // Swedish is NLLB-only (not in Apple Translation)
        XCTAssertTrue(NLLBLanguageCodes.isNLLBOnlyLanguage("sv"))
        XCTAssertTrue(NLLBLanguageCodes.isNLLBOnlyLanguage("fi"))
        // English is Apple Translation supported
        XCTAssertFalse(NLLBLanguageCodes.isNLLBOnlyLanguage("en"))
        XCTAssertFalse(NLLBLanguageCodes.isNLLBOnlyLanguage("ja"))
    }
}
