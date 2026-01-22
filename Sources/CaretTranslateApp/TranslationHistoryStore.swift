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
    private let settings: SettingsStore
    private let storageKey = "history.entries"

    init(userDefaults: UserDefaults = .standard, settings: SettingsStore = SettingsStore()) {
        self.userDefaults = userDefaults
        self.settings = settings
        self.entries = TranslationHistoryStore.loadEntries(from: userDefaults, key: storageKey)
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
        userDefaults.removeObject(forKey: storageKey)
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
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadEntries(from defaults: UserDefaults, key: String) -> [TranslationHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TranslationHistoryEntry].self, from: data) else {
            return []
        }
        return decoded
    }
}
