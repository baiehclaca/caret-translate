import XCTest
@testable import CaretTranslateCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultsToSlovakToEnglish() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.defaults")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.defaults")
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.sourceLanguage, Language(code: "sk"))
        XCTAssertEqual(store.targetLanguage, Language(code: "en"))
        XCTAssertEqual(store.shortcutMode, .doubleTap)
        XCTAssertEqual(store.hotkeyBinding, HotkeyBinding.default)
        XCTAssertTrue(store.previewEnabled)
        XCTAssertTrue(store.historyEnabled)
        XCTAssertEqual(store.historyRetentionCount, 200)
        XCTAssertEqual(store.historyRetentionDays, 14)
        XCTAssertEqual(store.allowlistBundleIds, [])
        XCTAssertEqual(store.denylistBundleIds, [])
        XCTAssertEqual(store.translationFormality, .default)
        XCTAssertEqual(store.performanceMode, .balanced)
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
        store.historyEnabled = false
        store.historyRetentionCount = 50
        store.historyRetentionDays = 7
        store.allowlistBundleIds = ["com.apple.TextEdit"]
        store.denylistBundleIds = ["com.apple.Terminal"]
        store.translationFormality = .more
        store.performanceMode = .fast

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.shortcutMode, .hotkey)
        XCTAssertEqual(reloaded.hotkeyBinding, HotkeyBinding(key: "g", modifiers: [.command, .option]))
        XCTAssertFalse(reloaded.previewEnabled)
        XCTAssertFalse(reloaded.historyEnabled)
        XCTAssertEqual(reloaded.historyRetentionCount, 50)
        XCTAssertEqual(reloaded.historyRetentionDays, 7)
        XCTAssertEqual(reloaded.allowlistBundleIds, ["com.apple.TextEdit"])
        XCTAssertEqual(reloaded.denylistBundleIds, ["com.apple.Terminal"])
        XCTAssertEqual(reloaded.translationFormality, .more)
        XCTAssertEqual(reloaded.performanceMode, .fast)
    }
}
