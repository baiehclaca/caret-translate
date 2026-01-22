import Foundation

// @unchecked Sendable because callers control access to non-thread-safe translators.
public struct TranslationService: @unchecked Sendable {
    private let sentenceSelector: SentenceSelector
    private let sentenceTranslator: Translator
    private let wordSelector: WordSelector
    private let wordTranslator: Translator
    private let contextualFixer: ContextualFixer?

    public init(
        sentenceSelector: SentenceSelector,
        sentenceTranslator: Translator,
        wordSelector: WordSelector,
        wordTranslator: Translator,
        contextualFixer: ContextualFixer? = nil
    ) {
        self.sentenceSelector = sentenceSelector
        self.sentenceTranslator = sentenceTranslator
        self.wordSelector = wordSelector
        self.wordTranslator = wordTranslator
        self.contextualFixer = contextualFixer
    }

    public init(selector: WordSelector, translator: Translator) {
        self.init(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: translator,
            wordSelector: selector,
            wordTranslator: translator
        )
    }

    public func replacement(for snapshot: TextSnapshot, from: Language, to: Language) async throws -> TextReplacement? {
        let wordSelection = wordSelector.selectNearestWord(in: snapshot)
        if let sentenceSelection = sentenceSelector.selectSentence(in: snapshot) {
            do {
                if let translated = try await sentenceTranslator.translate(sentenceSelection.sentence, from: from, to: to) {
                    if let contextualFixer,
                       let wordSelection,
                       let context = contextualFixerContext(
                           sentenceSelection: sentenceSelection,
                           wordSelection: wordSelection,
                           translatedSentence: translated,
                           from: from,
                           to: to
                       ),
                       let fixed = try await contextualFixer.fix(context) {
                        return TextReplacement(rangeUTF16: sentenceSelection.rangeUTF16, replacement: fixed)
                    }
                    return TextReplacement(rangeUTF16: sentenceSelection.rangeUTF16, replacement: translated)
                }
            } catch {
                // Fall through to word-level translation.
            }
        }

        guard let wordSelection else {
            return nil
        }
        guard let translated = try await wordTranslator.translate(wordSelection.word, from: from, to: to) else {
            return nil
        }
        return TextReplacement(rangeUTF16: wordSelection.rangeUTF16, replacement: translated)
    }

    private func contextualFixerContext(
        sentenceSelection: SentenceSelection,
        wordSelection: WordSelection,
        translatedSentence: String,
        from: Language,
        to: Language
    ) -> ContextualFixerContext? {
        let sentenceRange = sentenceSelection.rangeUTF16
        let wordRange = wordSelection.rangeUTF16
        guard wordRange.location >= sentenceRange.location,
              wordRange.location + wordRange.length <= sentenceRange.location + sentenceRange.length else {
            return nil
        }
        let localRange = NSRange(
            location: wordRange.location - sentenceRange.location,
            length: wordRange.length
        )
        return ContextualFixerContext(
            sourceSentence: sentenceSelection.sentence,
            sourceWordRangeUTF16: localRange,
            translatedSentence: translatedSentence,
            sourceLanguage: from,
            targetLanguage: to
        )
    }
}
