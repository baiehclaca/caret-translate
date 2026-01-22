import Foundation
import CaretTranslateCore

struct PrivacyFilter {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func isAllowed(bundleId: String?, isSecureField: Bool) -> Bool {
        if isSecureField {
            return false
        }

        let denylist = Set(settings.denylistBundleIds)
        let allowlist = Set(settings.allowlistBundleIds)

        if let bundleId {
            if denylist.contains(bundleId) {
                return false
            }
            if !allowlist.isEmpty {
                return allowlist.contains(bundleId)
            }
            return true
        }

        return allowlist.isEmpty
    }
}
