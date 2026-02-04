import Foundation

/// Restores common missing diacritics for specific languages using lightweight phrase rules.
public struct DiacriticRestorer: @unchecked Sendable {
    private struct PhraseRule {
        let languageCode: String
        let regex: NSRegularExpression
        let template: String
    }

    private let rules: [PhraseRule]
    private let logger: (@Sendable (String) -> Void)?

    /// Creates a diacritic restorer with built-in phrase rules.
    public init(logger: (@Sendable (String) -> Void)? = nil) {
        self.rules = DiacriticRestorer.defaultRules()
        self.logger = logger
    }

    /// Returns text with restored diacritics when a matching rule applies.
    public func restore(_ text: String, language: Language) -> String? {
        let normalizedLanguage = language.code.lowercased()
        guard let diacritics = DiacriticRestorer.diacriticsByLanguage[normalizedLanguage] else {
            return nil
        }

        if text.rangeOfCharacter(from: diacritics) != nil {
            return nil
        }

        var updated = text
        var didChange = false

        for rule in rules where rule.languageCode == normalizedLanguage {
            let matches = rule.regex.matches(in: updated, range: NSRange(updated.startIndex..., in: updated))
            guard !matches.isEmpty else {
                continue
            }
            for match in matches.reversed() {
                guard match.range.location != NSNotFound,
                      let range = Range(match.range, in: updated) else {
                    continue
                }
                let matchedText = String(updated[range])
                let replacement = rule.regex.replacementString(
                    for: match,
                    in: updated,
                    offset: 0,
                    template: rule.template
                )
                let adjustedReplacement = applyCasing(original: matchedText, replacement: replacement)
                updated.replaceSubrange(range, with: adjustedReplacement)
                didChange = true
            }
        }

        if didChange {
            logger?("INFO: Diacritic restoration applied for \(normalizedLanguage).")
            return updated
        }

        return nil
    }

    /// Attempts restoration for the first matching language in the candidate list.
    public func restore(_ text: String, candidates: [Language]) -> (text: String, language: Language)? {
        for candidate in candidates {
            if let restored = restore(text, language: candidate) {
                return (restored, candidate)
            }
        }
        return nil
    }

    /// Adjusts replacement casing to match the original match's casing.
    private func applyCasing(original: String, replacement: String) -> String {
        if original == original.uppercased() {
            return replacement.uppercased()
        }
        if original.first?.isUppercase == true {
            let prefix = replacement.prefix(1).uppercased()
            let suffix = replacement.dropFirst()
            return prefix + suffix
        }
        return replacement
    }

    /// Returns built-in phrase rules for supported languages.
    private static func defaultRules() -> [PhraseRule] {
        [
            makeRule(
                languageCode: "sk",
                pattern: "\\\\bako\\\\s+sa\\\\s+mas\\\\b([!?.,])?",
                template: "ako sa máš$1"
            ),
            makeRule(
                languageCode: "cs",
                pattern: "\\\\bjak\\\\s+se\\\\s+mas\\\\b([!?.,])?",
                template: "jak se máš$1"
            ),
        ]
        .compactMap { $0 }
    }

    /// Creates a phrase rule with case-insensitive matching.
    private static func makeRule(languageCode: String, pattern: String, template: String) -> PhraseRule? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        return PhraseRule(languageCode: languageCode, regex: regex, template: template)
    }

    /// Maps language codes to the diacritic characters that indicate already-correct text.
    private static let diacriticsByLanguage: [String: CharacterSet] = [
        "sk": CharacterSet(charactersIn: "áäčďéíĺľňóôŕšťúýžÁÄČĎÉÍĹĽŇÓÔŔŠŤÚÝŽ"),
        "cs": CharacterSet(charactersIn: "áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ"),
    ]

    /// Returns the language codes supported by diacritic restoration.
    public static var supportedLanguageCodes: [String] {
        Array(diacriticsByLanguage.keys).sorted()
    }
}
