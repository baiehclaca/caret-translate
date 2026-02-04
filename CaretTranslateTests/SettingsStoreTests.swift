import XCTest
@testable import CaretTranslate

final class SettingsStoreTests: XCTestCase {
    func testDefaultsToAutoToEnglish() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.defaults")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.defaults")
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.sourceLanguage, Language(code: "auto"))
        XCTAssertEqual(store.targetLanguage, Language(code: "en"))
        XCTAssertEqual(store.shortcutMode, .doubleTap)
        XCTAssertEqual(store.hotkeyBinding, HotkeyBinding.default)
        XCTAssertTrue(store.previewEnabled)
        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertFalse(store.onboardingCompleted)
        XCTAssertTrue(store.historyEnabled)
        XCTAssertEqual(store.historyRetentionCount, 200)
        XCTAssertEqual(store.historyRetentionDays, 14)
    }

    func testPersistsLanguageSelection() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.persist")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.persist")
        let store = SettingsStore(userDefaults: defaults)

        store.sourceLanguage = Language(code: "en")
        store.targetLanguage = Language(code: "sk")

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.sourceLanguage, Language(code: "en"))
        XCTAssertEqual(reloaded.targetLanguage, Language(code: "sk"))
    }

    func testPersistsAdvancedSettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.advanced")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.advanced")
        let store = SettingsStore(userDefaults: defaults)

        store.shortcutMode = .hotkey
        store.hotkeyBinding = HotkeyBinding(key: "g", modifiers: [.command, .option])
        store.previewEnabled = false
        store.launchAtLoginEnabled = false
        store.onboardingCompleted = true
        store.historyEnabled = false
        store.historyRetentionCount = 50
        store.historyRetentionDays = 7
        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.shortcutMode, .hotkey)
        XCTAssertEqual(reloaded.hotkeyBinding, HotkeyBinding(key: "g", modifiers: [.command, .option]))
        XCTAssertFalse(reloaded.previewEnabled)
        XCTAssertFalse(reloaded.launchAtLoginEnabled)
        XCTAssertTrue(reloaded.onboardingCompleted)
        XCTAssertFalse(reloaded.historyEnabled)
        XCTAssertEqual(reloaded.historyRetentionCount, 50)
        XCTAssertEqual(reloaded.historyRetentionDays, 7)
    }

}
