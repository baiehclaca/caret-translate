import Foundation
import CaretTranslateCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var sourceCode: String
    @Published var targetCode: String
    @Published var apiKey: String
    @Published var sourceLanguages: [LanguageOption] = []
    @Published var targetLanguages: [LanguageOption] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var previewEnabled: Bool {
        didSet {
            settings.previewEnabled = previewEnabled
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
    @Published var translationFormality: TranslationFormality {
        didSet {
            settings.translationFormality = translationFormality
            notifyChange()
        }
    }
    @Published var performanceMode: PerformanceMode {
        didSet {
            settings.performanceMode = performanceMode
            notifyChange()
        }
    }
    @Published private(set) var allowlistBundleIds: [String]
    @Published private(set) var denylistBundleIds: [String]

    private let settings: SettingsStore
    private let apiKeyStore: ApiKeyStore
    private let catalogStore: LanguageCatalogStore

    init(
        settings: SettingsStore = SettingsStore(),
        apiKeyStore: ApiKeyStore = ApiKeyStore(),
        catalogStore: LanguageCatalogStore = LanguageCatalogStore()
    ) {
        self.settings = settings
        self.apiKeyStore = apiKeyStore
        self.catalogStore = catalogStore
        self.sourceCode = settings.sourceLanguage.code
        self.targetCode = settings.targetLanguage.code
        self.apiKey = apiKeyStore.apiKey ?? ""
        self.previewEnabled = settings.previewEnabled
        self.historyEnabled = settings.historyEnabled
        self.historyRetentionCount = settings.historyRetentionCount
        self.historyRetentionDays = settings.historyRetentionDays
        self.shortcutMode = settings.shortcutMode
        self.hotkeyKey = settings.hotkeyBinding.key
        self.hotkeyModifiers = settings.hotkeyBinding.modifiers
        self.translationFormality = settings.translationFormality
        self.performanceMode = settings.performanceMode
        self.allowlistBundleIds = settings.allowlistBundleIds
        self.denylistBundleIds = settings.denylistBundleIds
    }

    func saveApiKey() {
        apiKeyStore.apiKey = apiKey
        notifyChange()
    }

    func refreshLanguages() {
        Task {
            await loadLanguages()
        }
    }

    func loadLanguages() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            sourceLanguages = []
            targetLanguages = []
            errorMessage = "Enter your DeepL API key to load languages."
            return
        }

        isLoading = true
        errorMessage = nil
        let client = DeepLClient(authKey: trimmedKey)
        do {
            let sources = try await client.fetchLanguages(type: .source)
            let targets = try await client.fetchLanguages(type: .target)
            sourceLanguages = ([LanguageOption.auto] + sources.map(LanguageOption.init)).sorted()
            targetLanguages = targets.map(LanguageOption.init).sorted()
            catalogStore.save(source: sourceLanguages, target: targetLanguages)
            normalizeSelection()
        } catch {
            errorMessage = "Failed to load languages. Check your API key."
        }
        isLoading = false
    }

    func updateSource(code: String) {
        settings.sourceLanguage = Language(code: code)
        notifyChange()
    }

    func updateTarget(code: String) {
        settings.targetLanguage = Language(code: code)
        notifyChange()
    }

    func addAllowlist(bundleId: String) {
        guard !bundleId.isEmpty else {
            return
        }
        var updated = Set(allowlistBundleIds)
        updated.insert(bundleId)
        allowlistBundleIds = updated.sorted()
        settings.allowlistBundleIds = allowlistBundleIds
        notifyChange()
    }

    func removeAllowlist(bundleIds: Set<String>) {
        guard !bundleIds.isEmpty else {
            return
        }
        allowlistBundleIds.removeAll { bundleIds.contains($0) }
        settings.allowlistBundleIds = allowlistBundleIds
        notifyChange()
    }

    func addDenylist(bundleId: String) {
        guard !bundleId.isEmpty else {
            return
        }
        var updated = Set(denylistBundleIds)
        updated.insert(bundleId)
        denylistBundleIds = updated.sorted()
        settings.denylistBundleIds = denylistBundleIds
        notifyChange()
    }

    func removeDenylist(bundleIds: Set<String>) {
        guard !bundleIds.isEmpty else {
            return
        }
        denylistBundleIds.removeAll { bundleIds.contains($0) }
        settings.denylistBundleIds = denylistBundleIds
        notifyChange()
    }

    private func normalizeSelection() {
        if !sourceLanguages.isEmpty, !sourceLanguages.contains(where: { $0.code == sourceCode }) {
            sourceCode = sourceLanguages[0].code
            updateSource(code: sourceCode)
        }
        if !targetLanguages.isEmpty, !targetLanguages.contains(where: { $0.code == targetCode }) {
            targetCode = targetLanguages[0].code
            updateTarget(code: targetCode)
        }
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
