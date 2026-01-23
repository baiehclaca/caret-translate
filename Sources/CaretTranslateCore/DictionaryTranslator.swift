import Foundation

public protocol Translator: Sendable {
    func translate(_ text: String, from: Language, to: Language) async throws -> String?
}

public struct DictionaryTranslator: Translator {
    private let entries: [LanguagePair: [String: String]]

    public init(entries: [LanguagePair: [String: String]]) {
        self.entries = entries
    }

    public init(resourceName: String) throws {
        try self.init(resourceName: resourceName, bundle: .module)
    }

    public init(resourceName: String, bundle: Bundle) throws {
        let url = try DictionaryTranslator.resourceURL(named: resourceName, bundle: bundle)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: [String: String]].self, from: data)
        self.entries = DictionaryTranslator.convert(decoded)
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        let key = LanguagePair(from: from, to: to)
        guard let map = entries[key] else {
            return nil
        }
        let lookup = text.lowercased()
        guard let translated = map[lookup] else {
            return nil
        }
        return applyCase(of: text, to: translated)
    }

    private func applyCase(of original: String, to translated: String) -> String {
        let lowercased = original.lowercased()
        let uppercased = original.uppercased()
        if original == uppercased {
            return translated.uppercased()
        }
        if original == lowercased {
            return translated
        }
        let first = original.prefix(1)
        let rest = original.dropFirst()
        if first == first.uppercased() && rest == rest.lowercased() {
            return translated.prefix(1).uppercased() + translated.dropFirst().lowercased()
        }
        return translated
    }

    private static func resourceURL(named resourceName: String, bundle: Bundle) throws -> URL {
        if let url = bundle.url(forResource: resourceName, withExtension: "json") {
            return url
        }
        throw DictionaryTranslatorError.resourceNotFound(resourceName)
    }

    private static func convert(_ decoded: [String: [String: String]]) -> [LanguagePair: [String: String]] {
        var entries: [LanguagePair: [String: String]] = [:]
        for (key, value) in decoded {
            let parts = key.split(separator: "-")
            guard parts.count == 2 else {
                continue
            }
            let pair = LanguagePair(
                from: Language(code: String(parts[0])),
                to: Language(code: String(parts[1]))
            )
            entries[pair] = value
        }
        return entries
    }
}

public enum DictionaryTranslatorError: Error {
    case resourceNotFound(String)
}
