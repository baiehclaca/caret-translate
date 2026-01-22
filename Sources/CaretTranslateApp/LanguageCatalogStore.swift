import Foundation

struct LanguageCatalogItem: Codable, Equatable, Identifiable {
    let id: String
    let code: String
    let name: String

    init(code: String, name: String) {
        self.id = code
        self.code = code
        self.name = name
    }
}

final class LanguageCatalogStore {
    private let userDefaults: UserDefaults
    private let sourceKey = "settings.languages.sourceCatalog"
    private let targetKey = "settings.languages.targetCatalog"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(source: [LanguageOption], target: [LanguageOption]) {
        let sourceItems = source.map { LanguageCatalogItem(code: $0.code, name: $0.name) }
        let targetItems = target.map { LanguageCatalogItem(code: $0.code, name: $0.name) }
        save(items: sourceItems, key: sourceKey)
        save(items: targetItems, key: targetKey)
    }

    func loadSource() -> [LanguageCatalogItem] {
        load(key: sourceKey)
    }

    func loadTarget() -> [LanguageCatalogItem] {
        load(key: targetKey)
    }

    private func save(items: [LanguageCatalogItem], key: String) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }

    private func load(key: String) -> [LanguageCatalogItem] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LanguageCatalogItem].self, from: data) else {
            return []
        }
        return decoded
    }
}
