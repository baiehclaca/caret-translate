import Foundation

public struct ContextualFixerPrompt {
    public init() {}

    public func buildPrompt(context: ContextualFixerContext) -> String? {
        guard let taggedSource = context.taggedSourceSentence() else {
            return nil
        }

        return """
You are a multilingual grammar-and-inflection fixer.

Task:
Given:
- SOURCE_SENTENCE in the source language. The word to focus on is wrapped in <source>...</source>.
- TRANSLATED_SENTENCE in the target language.

Update only the target-language word or short phrase that corresponds to the marked source word so the translation is grammatical. Do not rewrite other parts. Preserve punctuation and spacing. If you cannot confidently map the word, return the original TRANSLATED_SENTENCE unchanged.

Return ONLY valid JSON:
{"corrected_sentence":"...","replacement":"...","changed":true}

Where:
- corrected_sentence is the full target-language sentence.
- replacement is the corrected word/phrase (or the original if unchanged).
- changed is true only if you changed it.

TARGET_LANG: \(context.targetLanguage.code)
SOURCE_SENTENCE: \(taggedSource)
TRANSLATED_SENTENCE: \(context.translatedSentence)
"""
    }
}
