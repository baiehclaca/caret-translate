import XCTest
@testable import CaretTranslateApp
@testable import CaretTranslateCore

final class CustomDictionaryStoreTests: XCTestCase {
    @MainActor
    func testAddEntryPersistsAndBuildsMap() {
        let defaults = UserDefaults(suiteName: "CustomDictionaryStoreTests.add")!
        defaults.removePersistentDomain(forName: "CustomDictionaryStoreTests.add")
        let store = CustomDictionaryStore(userDefaults: defaults)

        store.addEntry(source: "Hello", target: "Ahoj", sourceLanguage: "en", targetLanguage: "sk")

        XCTAssertEqual(store.entries.count, 1)
        let map = store.entriesMap()
        let pair = LanguagePair(from: Language(code: "en"), to: Language(code: "sk"))
        XCTAssertEqual(map[pair]?["hello"], "Ahoj")
    }

    @MainActor
    func testRemoveEntries() {
        let defaults = UserDefaults(suiteName: "CustomDictionaryStoreTests.remove")!
        defaults.removePersistentDomain(forName: "CustomDictionaryStoreTests.remove")
        let store = CustomDictionaryStore(userDefaults: defaults)

        store.addEntry(source: "Hello", target: "Ahoj", sourceLanguage: "en", targetLanguage: "sk")
        let id = store.entries.first?.id

        store.remove(ids: id.map { [$0] } ?? [])

        XCTAssertTrue(store.entries.isEmpty)
    }
}
