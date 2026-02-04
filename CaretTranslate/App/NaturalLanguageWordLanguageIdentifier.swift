import Foundation
import NaturalLanguage

final class NaturalLanguageWordLanguageIdentifier: WordLanguageIdentifying, @unchecked Sendable {
    private let logger: ((String) -> Void)?

    /// Creates a NaturalLanguage-backed word language identifier with optional logging.
    init(logger: ((String) -> Void)? = nil) {
        self.logger = logger
    }

    /// Returns the dominant language for a full text, or nil when undetermined.
    func dominantLanguage(for text: String) -> Language? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log("INFO: Dominant language detection skipped due to empty text.")
            return nil
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else {
            log("INFO: Dominant language undetermined.")
            return nil
        }
        guard let normalized = normalizeLanguageCode(language.rawValue) else {
            log("INFO: Dominant language undetermined after normalization.")
            return nil
        }
        log("INFO: Dominant language detected code=\(normalized).")
        return Language(code: normalized)
    }

    /// Returns the language for the word that intersects the provided UTF-16 range in `text`.
    func language(for text: String, wordRangeUTF16: NSRange) -> Language? {
        let nsText = text as NSString
        guard wordRangeUTF16.location >= 0,
              wordRangeUTF16.length > 0,
              wordRangeUTF16.location + wordRangeUTF16.length <= nsText.length else {
            log("WARNING: Word language detection skipped due to invalid range.")
            return nil
        }

        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text
        let index = String.Index(utf16Offset: wordRangeUTF16.location, in: text)
        let (tag, tokenRange) = tagger.tag(at: index, unit: .word, scheme: .language)
        let tokenNSRange = NSRange(tokenRange, in: text)

        guard tokenNSRange.location != NSNotFound,
              tokenNSRange.location <= wordRangeUTF16.location,
              tokenNSRange.location + tokenNSRange.length >= wordRangeUTF16.location + wordRangeUTF16.length else {
            log("INFO: Word language undetermined due to token mismatch.")
            return nil
        }
        guard let rawValue = tag?.rawValue,
              let normalized = normalizeLanguageCode(rawValue) else {
            log("INFO: Word language undetermined.")
            return nil
        }
        log("INFO: Word language detected code=\(normalized).")
        return Language(code: normalized)
    }

    /// Normalizes a language code by lowercasing and stripping region subtags.
    private func normalizeLanguageCode(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let lowercased = trimmed.lowercased()
        guard lowercased != "und" else {
            return nil
        }
        let base = lowercased.split(separator: "-").first.map(String.init) ?? lowercased
        return base.isEmpty ? nil : base
    }

    /// Emits a log message if a logger is configured.
    private func log(_ message: String) {
        logger?(message)
    }
}
