import XCTest
@testable import CaretTranslateApp
@testable import CaretTranslateCore

final class PrivacyFilterTests: XCTestCase {
    func testAllowsWhenNoListsAndNotSecure() {
        let settings = SettingsStore(userDefaults: UserDefaults(suiteName: "PrivacyFilterTests.default")!)
        let filter = PrivacyFilter(settings: settings)

        XCTAssertTrue(filter.isAllowed(bundleId: "com.apple.TextEdit", isSecureField: false))
    }

    func testBlocksWhenSecureField() {
        let settings = SettingsStore(userDefaults: UserDefaults(suiteName: "PrivacyFilterTests.secure")!)
        let filter = PrivacyFilter(settings: settings)

        XCTAssertFalse(filter.isAllowed(bundleId: "com.apple.TextEdit", isSecureField: true))
    }

    func testRespectsAllowlist() {
        let defaults = UserDefaults(suiteName: "PrivacyFilterTests.allow")!
        defaults.removePersistentDomain(forName: "PrivacyFilterTests.allow")
        let settings = SettingsStore(userDefaults: defaults)
        settings.allowlistBundleIds = ["com.apple.TextEdit"]
        let filter = PrivacyFilter(settings: settings)

        XCTAssertTrue(filter.isAllowed(bundleId: "com.apple.TextEdit", isSecureField: false))
        XCTAssertFalse(filter.isAllowed(bundleId: "com.apple.Terminal", isSecureField: false))
        XCTAssertFalse(filter.isAllowed(bundleId: nil, isSecureField: false))
    }

    func testRespectsDenylist() {
        let defaults = UserDefaults(suiteName: "PrivacyFilterTests.deny")!
        defaults.removePersistentDomain(forName: "PrivacyFilterTests.deny")
        let settings = SettingsStore(userDefaults: defaults)
        settings.denylistBundleIds = ["com.apple.Terminal"]
        let filter = PrivacyFilter(settings: settings)

        XCTAssertFalse(filter.isAllowed(bundleId: "com.apple.Terminal", isSecureField: false))
        XCTAssertTrue(filter.isAllowed(bundleId: "com.apple.TextEdit", isSecureField: false))
    }
}
