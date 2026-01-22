import XCTest
@testable import CaretTranslateApp
@testable import CaretTranslateCore

final class TranslationHistoryStoreTests: XCTestCase {
    @MainActor
    func testAppendRespectsHistoryDisabled() {
        let defaults = UserDefaults(suiteName: "TranslationHistoryStoreTests.disabled")!
        defaults.removePersistentDomain(forName: "TranslationHistoryStoreTests.disabled")
        let settings = SettingsStore(userDefaults: defaults)
        settings.historyEnabled = false
        let store = TranslationHistoryStore(userDefaults: defaults, settings: settings)

        store.append(makeEntry(id: "1"))

        XCTAssertEqual(store.entries.count, 0)
    }

    @MainActor
    func testAppendRespectsRetentionCount() {
        let defaults = UserDefaults(suiteName: "TranslationHistoryStoreTests.count")!
        defaults.removePersistentDomain(forName: "TranslationHistoryStoreTests.count")
        let settings = SettingsStore(userDefaults: defaults)
        settings.historyRetentionCount = 2
        settings.historyRetentionDays = 10_000
        let store = TranslationHistoryStore(userDefaults: defaults, settings: settings)

        store.append(makeEntry(id: "1"))
        store.append(makeEntry(id: "2"))
        store.append(makeEntry(id: "3"))

        XCTAssertEqual(store.entries.map(\.id), ["3", "2"])
    }

    @MainActor
    func testAppendDropsEntriesOlderThanRetentionDays() {
        let defaults = UserDefaults(suiteName: "TranslationHistoryStoreTests.days")!
        defaults.removePersistentDomain(forName: "TranslationHistoryStoreTests.days")
        let settings = SettingsStore(userDefaults: defaults)
        settings.historyRetentionDays = 1
        let store = TranslationHistoryStore(userDefaults: defaults, settings: settings)

        let now = Date()
        store.append(makeEntry(id: "recent", date: now))
        store.append(makeEntry(id: "old", date: now.addingTimeInterval(-60 * 60 * 48)))
        store.prune(referenceDate: now)

        XCTAssertEqual(store.entries.map(\.id), ["recent"])
    }

    @MainActor
    func testPersistsEntries() {
        let defaults = UserDefaults(suiteName: "TranslationHistoryStoreTests.persist")!
        defaults.removePersistentDomain(forName: "TranslationHistoryStoreTests.persist")
        let settings = SettingsStore(userDefaults: defaults)
        settings.historyRetentionDays = 10_000
        let store = TranslationHistoryStore(userDefaults: defaults, settings: settings)

        store.append(makeEntry(id: "1"))

        let reloaded = TranslationHistoryStore(userDefaults: defaults, settings: settings)
        XCTAssertEqual(reloaded.entries.map(\.id), ["1"])
    }
}

private func makeEntry(id: String, date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> TranslationHistoryEntry {
    TranslationHistoryEntry(
        id: id,
        timestamp: date,
        sourceText: "hello",
        translatedText: "ahoj",
        sourceLanguage: "en",
        targetLanguage: "sk",
        appBundleId: "com.apple.TextEdit"
    )
}
