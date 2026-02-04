import Foundation

public protocol WordLanguageIdentifying: Sendable {
    /// Returns the dominant language for a full text, or nil when undetermined.
    func dominantLanguage(for text: String) -> Language?
    /// Returns the language for the word that intersects the provided UTF-16 range in `text`.
    func language(for text: String, wordRangeUTF16: NSRange) -> Language?
}
