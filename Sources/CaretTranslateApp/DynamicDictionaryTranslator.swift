import Foundation
import CaretTranslateCore

struct DynamicDictionaryTranslator: Translator, @unchecked Sendable {
    let mapProvider: () -> [LanguagePair: [String: String]]

    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        let map = mapProvider()
        let key = LanguagePair(from: from, to: to)
        guard let entries = map[key] else {
            return nil
        }
        let lookup = text.lowercased()
        guard let translated = entries[lookup] else {
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
}
