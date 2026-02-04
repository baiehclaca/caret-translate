import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var sourceCode: String
    @Published var targetCode: String
    @Published var previewEnabled: Bool {
        didSet {
            settings.previewEnabled = previewEnabled
            notifyChange()
        }
    }
    @Published var launchAtLoginEnabled: Bool {
        didSet {
            settings.launchAtLoginEnabled = launchAtLoginEnabled
            notifyChange()
        }
    }
    @Published var historyEnabled: Bool {
        didSet {
            settings.historyEnabled = historyEnabled
            notifyChange()
        }
    }
    @Published var historyRetentionCount: Int {
        didSet {
            settings.historyRetentionCount = historyRetentionCount
            notifyChange()
        }
    }
    @Published var historyRetentionDays: Int {
        didSet {
            settings.historyRetentionDays = historyRetentionDays
            notifyChange()
        }
    }
    @Published var shortcutMode: ShortcutMode {
        didSet {
            settings.shortcutMode = shortcutMode
            notifyChange()
        }
    }
    @Published var hotkeyKey: String {
        didSet {
            let normalized = normalizeHotkeyKey(hotkeyKey)
            if normalized != hotkeyKey {
                hotkeyKey = normalized
                return
            }
            updateHotkeyBinding()
        }
    }
    @Published var hotkeyModifiers: HotkeyModifier {
        didSet {
            updateHotkeyBinding()
        }
    }

    private let settings: SettingsStore

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.sourceCode = settings.sourceLanguage.code
        self.targetCode = settings.targetLanguage.code
        self.previewEnabled = settings.previewEnabled
        self.launchAtLoginEnabled = settings.launchAtLoginEnabled
        self.historyEnabled = settings.historyEnabled
        self.historyRetentionCount = settings.historyRetentionCount
        self.historyRetentionDays = settings.historyRetentionDays
        self.shortcutMode = settings.shortcutMode
        self.hotkeyKey = settings.hotkeyBinding.key
        self.hotkeyModifiers = settings.hotkeyBinding.modifiers
    }

    func updateSource(code: String) {
        settings.sourceLanguage = Language(code: code)
        notifyChange()
    }

    func updateTarget(code: String) {
        settings.targetLanguage = Language(code: code)
        notifyChange()
    }

    private func updateHotkeyBinding() {
        let binding = HotkeyBinding(key: hotkeyKey, modifiers: hotkeyModifiers)
        settings.hotkeyBinding = binding
        notifyChange()
    }

    private func normalizeHotkeyKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : String(trimmed.lowercased().prefix(1))
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}
