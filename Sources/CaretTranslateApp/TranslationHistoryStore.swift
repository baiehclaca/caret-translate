import Foundation
import CaretTranslateCore

struct TranslationHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let appBundleId: String?
}

@MainActor
final class TranslationHistoryStore: ObservableObject {
    @Published private(set) var entries: [TranslationHistoryEntry]

    private let userDefaults: UserDefaults
    private let encryptedStore: EncryptedUserDefaultsStore
    private let settings: SettingsStore
    private let storageKey = "history.entries.encrypted"
    private let legacyStorageKey = "history.entries"

    init(
        userDefaults: UserDefaults = .standard,
        encryptedStore: EncryptedUserDefaultsStore = EncryptedUserDefaultsStore(),
        settings: SettingsStore = SettingsStore()
    ) {
        self.userDefaults = userDefaults
        self.encryptedStore = encryptedStore
        self.settings = settings
        self.entries = TranslationHistoryStore.loadEntries(
            from: userDefaults,
            encryptedStore: encryptedStore,
            key: storageKey,
            legacyKey: legacyStorageKey
        )
    }

    func append(_ entry: TranslationHistoryEntry) {
        guard settings.historyEnabled else {
            return
        }
        entries.insert(entry, at: 0)
        prune(referenceDate: Date())
        persist()
    }

    func clear() {
        entries.removeAll()
        try? encryptedStore.set(nil, forKey: storageKey)
        userDefaults.removeObject(forKey: legacyStorageKey)
    }

    func prune(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-Double(settings.historyRetentionDays) * 86_400)
        entries = entries.filter { $0.timestamp >= cutoff }
        let maxCount = settings.historyRetentionCount
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        let encoded = data.base64EncodedString()
        try? encryptedStore.set(encoded, forKey: storageKey)
    }

    private static func loadEntries(
        from defaults: UserDefaults,
        encryptedStore: EncryptedUserDefaultsStore,
        key: String,
        legacyKey: String
    ) -> [TranslationHistoryEntry] {
        if let encrypted = try? encryptedStore.string(forKey: key),
           let data = Data(base64Encoded: encrypted),
           let decoded = try? JSONDecoder().decode([TranslationHistoryEntry].self, from: data) {
            return decoded
        }
        if let data = defaults.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([TranslationHistoryEntry].self, from: data) {
            let encoded = data.base64EncodedString()
            try? encryptedStore.set(encoded, forKey: key)
            defaults.removeObject(forKey: legacyKey)
            return decoded
        }
        return []
    }
}
