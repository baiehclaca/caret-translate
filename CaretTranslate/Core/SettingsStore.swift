import Foundation

public final class SettingsStore {
    private let userDefaults: UserDefaults
    private let sourceKey = "settings.sourceLanguage"
    private let targetKey = "settings.targetLanguage"
    private let shortcutModeKey = "settings.shortcutMode"
    private let hotkeyKey = "settings.hotkey.key"
    private let hotkeyModifiersKey = "settings.hotkey.modifiers"
    private let previewEnabledKey = "settings.previewEnabled"
    private let launchAtLoginKey = "settings.launchAtLogin"
    private let onboardingCompletedKey = "settings.onboardingCompleted"
    private let historyEnabledKey = "settings.history.enabled"
    private let historyRetentionCountKey = "settings.history.retentionCount"
    private let historyRetentionDaysKey = "settings.history.retentionDays"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var sourceLanguage: Language {
        get { language(forKey: sourceKey, fallback: "auto") }
        set { userDefaults.set(newValue.code, forKey: sourceKey) }
    }

    public var targetLanguage: Language {
        get { language(forKey: targetKey, fallback: "en") }
        set { userDefaults.set(newValue.code, forKey: targetKey) }
    }

    public var shortcutMode: ShortcutMode {
        get { enumValue(forKey: shortcutModeKey, fallback: .doubleTap) }
        set { userDefaults.set(newValue.rawValue, forKey: shortcutModeKey) }
    }

    public var hotkeyBinding: HotkeyBinding {
        get {
            let key = userDefaults.string(forKey: hotkeyKey) ?? HotkeyBinding.default.key
            let modifiersRaw = userDefaults.object(forKey: hotkeyModifiersKey) as? Int ?? HotkeyBinding.default.modifiers.rawValue
            return HotkeyBinding(key: key, modifiers: HotkeyModifier(rawValue: modifiersRaw))
        }
        set {
            userDefaults.set(newValue.key, forKey: hotkeyKey)
            userDefaults.set(newValue.modifiers.rawValue, forKey: hotkeyModifiersKey)
        }
    }

    public var previewEnabled: Bool {
        get { bool(forKey: previewEnabledKey, fallback: true) }
        set { userDefaults.set(newValue, forKey: previewEnabledKey) }
    }

    public var launchAtLoginEnabled: Bool {
        get { bool(forKey: launchAtLoginKey, fallback: false) }
        set { userDefaults.set(newValue, forKey: launchAtLoginKey) }
    }

    public var onboardingCompleted: Bool {
        get { bool(forKey: onboardingCompletedKey, fallback: false) }
        set { userDefaults.set(newValue, forKey: onboardingCompletedKey) }
    }

    public var historyEnabled: Bool {
        get { bool(forKey: historyEnabledKey, fallback: true) }
        set { userDefaults.set(newValue, forKey: historyEnabledKey) }
    }

    public var historyRetentionCount: Int {
        get { int(forKey: historyRetentionCountKey, fallback: 200, minimum: 1) }
        set { userDefaults.set(max(1, newValue), forKey: historyRetentionCountKey) }
    }

    public var historyRetentionDays: Int {
        get { int(forKey: historyRetentionDaysKey, fallback: 14, minimum: 1) }
        set { userDefaults.set(max(1, newValue), forKey: historyRetentionDaysKey) }
    }

    private func language(forKey key: String, fallback: String) -> Language {
        let stored = userDefaults.string(forKey: key)
        return Language(code: stored ?? fallback)
    }

    private func bool(forKey key: String, fallback: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return fallback
        }
        return userDefaults.bool(forKey: key)
    }

    private func int(forKey key: String, fallback: Int, minimum: Int) -> Int {
        guard userDefaults.object(forKey: key) != nil else {
            return fallback
        }
        return max(minimum, userDefaults.integer(forKey: key))
    }

    private func enumValue<T: RawRepresentable>(forKey key: String, fallback: T) -> T where T.RawValue == String {
        guard let raw = userDefaults.string(forKey: key),
              let value = T(rawValue: raw) else {
            return fallback
        }
        return value
    }

}
