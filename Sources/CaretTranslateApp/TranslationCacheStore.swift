import CryptoKit
import Foundation
import CaretTranslateCore

struct TranslationCacheKey {
    let text: String
    let source: Language
    let target: Language
    let formality: TranslationFormality

    var digest: String {
        let input = [
            source.code,
            target.code,
            formality.rawValue,
            text
        ].joined(separator: "|")
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

struct TranslationCacheEntry: Codable {
    let key: String
    let value: String
    let lastAccess: Date
}

struct TranslationCachePayload: Codable {
    let version: Int
    let entries: [TranslationCacheEntry]
}

actor TranslationCacheStore {
    static let shared = TranslationCacheStore()

    private let diskLimit: Int
    private let store: EncryptedUserDefaultsStore
    private let storageKey = "translation.cache.encrypted"
    private var entries: [String: TranslationCacheEntry] = [:]
    private var saveTask: Task<Void, Never>?
    private var needsSave = false

    init(
        diskLimit: Int = 1000,
        store: EncryptedUserDefaultsStore = EncryptedUserDefaultsStore()
    ) {
        self.diskLimit = max(200, diskLimit)
        self.store = store
        self.entries = TranslationCacheStore.load(from: store, key: storageKey)
    }

    func lookup(key: String) -> String? {
        guard let entry = entries[key] else {
            return nil
        }
        entries[key] = TranslationCacheEntry(
            key: entry.key,
            value: entry.value,
            lastAccess: Date()
        )
        return entry.value
    }

    func insert(_ value: String, for key: String) {
        entries[key] = TranslationCacheEntry(key: key, value: value, lastAccess: Date())
        pruneIfNeeded()
        scheduleSave()
    }

    func clear() {
        entries.removeAll()
        try? store.set(nil, forKey: storageKey)
        TranslationCacheStore.clearLegacyCacheFile()
    }

    private func pruneIfNeeded() {
        guard entries.count > diskLimit else {
            return
        }
        let sorted = entries.values.sorted { $0.lastAccess > $1.lastAccess }
        let keep = sorted.prefix(diskLimit)
        var next: [String: TranslationCacheEntry] = [:]
        for entry in keep {
            next[entry.key] = entry
        }
        entries = next
    }

    private func scheduleSave() {
        if saveTask != nil {
            needsSave = true
            return
        }
        saveTask = Task { [store, storageKey] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let snapshot = await self.snapshotEntries()
            TranslationCacheStore.persist(snapshot, to: store, key: storageKey)
            await self.markSaveComplete()
        }
    }

    private static func load(from store: EncryptedUserDefaultsStore, key: String) -> [String: TranslationCacheEntry] {
        if let encrypted = try? store.string(forKey: key),
           let data = Data(base64Encoded: encrypted),
           let payload = try? JSONDecoder().decode(TranslationCachePayload.self, from: data) {
            return payload.entries.reduce(into: [:]) { partial, entry in
                partial[entry.key] = entry
            }
        }
        if let legacy = loadLegacyCache() {
            let entries = legacy.entries.reduce(into: [:]) { partial, entry in
                partial[entry.key] = entry
            }
            persist(entries, to: store, key: key)
            clearLegacyCacheFile()
            return entries
        }
        return [:]
    }

    private static func persist(_ entries: [String: TranslationCacheEntry], to store: EncryptedUserDefaultsStore, key: String) {
        let payload = TranslationCachePayload(version: 1, entries: Array(entries.values))
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }
        let encoded = data.base64EncodedString()
        try? store.set(encoded, forKey: key)
    }

    private func snapshotEntries() async -> [String: TranslationCacheEntry] {
        entries
    }

    private func markSaveComplete() async {
        saveTask = nil
        if needsSave {
            needsSave = false
            scheduleSave()
        }
    }

    private static func defaultCacheURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("CaretTranslate", isDirectory: true)
        return folder.appendingPathComponent("translation-cache.json")
    }

    private static func loadLegacyCache() -> TranslationCachePayload? {
        let url = defaultCacheURL()
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(TranslationCachePayload.self, from: data)
    }

    private static func clearLegacyCacheFile() {
        let url = defaultCacheURL()
        try? FileManager.default.removeItem(at: url)
    }
}
