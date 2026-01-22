import CryptoKit
import XCTest
@testable import CaretTranslateCore

final class EncryptedUserDefaultsStoreTests: XCTestCase {
    func testRoundTripStoresAndLoadsValue() throws {
        let suiteName = "EncryptedUserDefaultsStoreTests.roundTrip"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let provider = InMemoryKeyProvider()
        let store = EncryptedUserDefaultsStore(userDefaults: defaults, keyProvider: provider)

        try store.set("secret-token", forKey: "apiKey")

        let loaded = try store.string(forKey: "apiKey")

        XCTAssertEqual(loaded, "secret-token")
    }

    func testNilRemovesValue() throws {
        let suiteName = "EncryptedUserDefaultsStoreTests.nil"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let provider = InMemoryKeyProvider()
        let store = EncryptedUserDefaultsStore(userDefaults: defaults, keyProvider: provider)

        try store.set("secret-token", forKey: "apiKey")
        try store.set(nil, forKey: "apiKey")

        let loaded = try store.string(forKey: "apiKey")

        XCTAssertNil(loaded)
    }
}

private final class InMemoryKeyProvider: SymmetricKeyProvider {
    private var stored: SymmetricKey?

    func loadKey() throws -> SymmetricKey? {
        stored
    }

    func saveKey(_ key: SymmetricKey) throws {
        stored = key
    }
}
