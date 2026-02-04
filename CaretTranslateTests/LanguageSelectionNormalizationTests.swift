import XCTest
@testable import CaretTranslate

@available(macOS 15.0, *)
final class LanguageSelectionNormalizationTests: XCTestCase {

    /// Ensures a target language of auto is normalized to English.
    func testNormalizesAutoTargetToEnglish() async {
        let settings = makeSettingsStore()
        settings.sourceLanguage = Language(code: "auto")
        settings.targetLanguage = Language(code: "auto")

        await MainActor.run {
            let coordinator = TranslationCoordinator(settings: settings)
            coordinator.normalizeLanguageSelectionIfNeeded()
        }

        XCTAssertEqual(settings.sourceLanguage.code, "auto")
        XCTAssertEqual(settings.targetLanguage.code, "en")
    }

    /// Ensures unsupported language codes are reset to safe defaults.
    func testResetsUnsupportedLanguagesToDefaults() async {
        let settings = makeSettingsStore()
        settings.sourceLanguage = Language(code: "xx")
        settings.targetLanguage = Language(code: "yy")

        await MainActor.run {
            let coordinator = TranslationCoordinator(settings: settings)
            coordinator.normalizeLanguageSelectionIfNeeded()
        }

        XCTAssertEqual(settings.sourceLanguage.code, "auto")
        XCTAssertEqual(settings.targetLanguage.code, "en")
    }

    /// Creates an isolated settings store backed by a unique UserDefaults suite.
    private func makeSettingsStore() -> SettingsStore {
        let suiteName = "CaretTranslateTests.LanguageNormalization.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite.")
            return SettingsStore()
        }
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(userDefaults: defaults)
    }
}
