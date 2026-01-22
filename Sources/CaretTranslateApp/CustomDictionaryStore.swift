import Foundation
import CaretTranslateCore

struct CustomDictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let source: String
    let target: String
    let sourceLanguage: String
    let targetLanguage: String
}

@MainActor
final class CustomDictionaryStore: ObservableObject {
    @Published private(set) var entries: [CustomDictionaryEntry]

    private let userDefaults: UserDefaults
    private let storageKey = "dictionary.custom.entries"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.entries = CustomDictionaryStore.loadEntries(from: userDefaults, key: storageKey)
    }

    func addEntry(source: String, target: String, sourceLanguage: String, targetLanguage: String) {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty, !trimmedTarget.isEmpty else {
            return
        }
        let entry = CustomDictionaryEntry(
            id: UUID(),
            source: trimmedSource,
            target: trimmedTarget,
            sourceLanguage: sourceLanguage.lowercased(),
            targetLanguage: targetLanguage.lowercased()
        )
        entries.insert(entry, at: 0)
        persist()
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else {
            return
        }
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func clear() {
        entries.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }

    func entriesMap() -> [LanguagePair: [String: String]] {
        let currentEntries = CustomDictionaryStore.loadEntries(from: userDefaults, key: storageKey)
        var map: [LanguagePair: [String: String]] = [:]
        for entry in currentEntries {
            let pair = LanguagePair(
                from: Language(code: entry.sourceLanguage),
                to: Language(code: entry.targetLanguage)
            )
            var dict = map[pair] ?? [:]
            dict[entry.source.lowercased()] = entry.target
            map[pair] = dict
        }
        return map
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadEntries(from defaults: UserDefaults, key: String) -> [CustomDictionaryEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomDictionaryEntry].self, from: data) else {
            return []
        }
        return decoded
    }
}
