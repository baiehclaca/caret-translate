import Foundation

// @unchecked Sendable because callers control access to non-thread-safe translators.
public struct TranslationService: @unchecked Sendable {
    private let sentenceSelector: SentenceSelector
    private let sentenceTranslator: Translator
    private let wordSelector: WordSelector
    private let wordTranslator: Translator
    private let contextualFixer: ContextualFixer?
    private let languageIdentifier: WordLanguageIdentifying?
    private let diacriticRestorer: DiacriticRestorer?
    private let decisionLogger: ((String) -> Void)?

    /// Creates a translation service with sentence and word translators plus optional context helpers.
    public init(
        sentenceSelector: SentenceSelector,
        sentenceTranslator: Translator,
        wordSelector: WordSelector,
        wordTranslator: Translator,
        contextualFixer: ContextualFixer? = nil,
        languageIdentifier: WordLanguageIdentifying? = nil,
        diacriticRestorer: DiacriticRestorer? = nil,
        decisionLogger: ((String) -> Void)? = nil
    ) {
        self.sentenceSelector = sentenceSelector
        self.sentenceTranslator = sentenceTranslator
        self.wordSelector = wordSelector
        self.wordTranslator = wordTranslator
        self.contextualFixer = contextualFixer
        self.languageIdentifier = languageIdentifier
        self.diacriticRestorer = diacriticRestorer
        self.decisionLogger = decisionLogger
    }

    /// Creates a translation service that uses the same translator for both sentence and word workflows.
    public init(selector: WordSelector, translator: Translator) {
        self.init(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: translator,
            wordSelector: selector,
            wordTranslator: translator
        )
    }

    /// Returns a replacement for the sentence or word nearest the caret when a translation is available.
    public func replacement(for snapshot: TextSnapshot, from: Language, to: Language) async throws -> TextReplacement? {
        let wordSelection = wordSelector.selectNearestWord(in: snapshot)
        if let sentenceSelection = sentenceSelector.selectSentence(in: snapshot) {
            if let mixedReplacement = try await translateForeignWords(
                sentenceSelection: sentenceSelection,
                from: from,
                to: to
            ) {
                logDecision("INFO: Using mixed-language word replacements.")
                return mixedReplacement
            }
            do {
                let sentenceToTranslate = restoreDiacriticsIfNeeded(
                    for: sentenceSelection.sentence,
                    from: from
                ) ?? sentenceSelection.sentence
                if let translated = try await sentenceTranslator.translate(sentenceToTranslate, from: from, to: to) {
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
        return try await translateWord(wordSelection, from: from, to: to)
    }

    /// Translates a single word selection and returns a replacement if available.
    private func translateWord(_ selection: WordSelection, from: Language, to: Language) async throws -> TextReplacement? {
        guard let translated = try await wordTranslator.translate(selection.word, from: from, to: to) else {
            return nil
        }
        return TextReplacement(rangeUTF16: selection.rangeUTF16, replacement: translated)
    }

    /// Translates words that are detected as non-target languages within the sentence.
    private func translateForeignWords(
        sentenceSelection: SentenceSelection,
        from: Language,
        to: Language
    ) async throws -> TextReplacement? {
        guard let languageIdentifier else {
            logDecision("INFO: Mixed-language scan skipped because no identifier is configured.")
            return nil
        }

        let words = wordSelector.selectWords(in: sentenceSelection.sentence)
        guard !words.isEmpty else {
            return nil
        }

        var wordLanguages: [(WordSelection, Language?)] = []
        var targetCount = 0
        var foreignCount = 0
        for word in words {
            let detected = languageIdentifier.language(
                for: sentenceSelection.sentence,
                wordRangeUTF16: word.rangeUTF16
            )
            if let detected {
                if detected.code == to.code {
                    targetCount += 1
                } else {
                    foreignCount += 1
                }
            }
            wordLanguages.append((word, detected))
        }

        let sentenceLanguage = languageIdentifier.dominantLanguage(for: sentenceSelection.sentence)
        let targetDominant = sentenceLanguage?.code == to.code && targetCount >= foreignCount && targetCount > 0
        guard foreignCount > 0, targetDominant else {
            let detectedCode = sentenceLanguage?.code ?? "und"
            logDecision(
                "INFO: Mixed-language scan skipped (dominant=\(detectedCode), target words=\(targetCount), foreign words=\(foreignCount))."
            )
            return nil
        }

        var replacements: [TextReplacement] = []
        for (word, detected) in wordLanguages {
            if let detected {
                if detected.code == to.code {
                    continue
                }
                do {
                    if let translated = try await wordTranslator.translate(word.word, from: detected, to: to) {
                        replacements.append(TextReplacement(rangeUTF16: word.rangeUTF16, replacement: translated))
                    }
                } catch {
                    logDecision("WARNING: Word translation failed for '\(word.word)'.")
                }
            } else {
                do {
                    if let translated = try await wordTranslator.translate(word.word, from: .auto, to: to),
                       shouldApplyTranslation(original: word.word, translated: translated) {
                        replacements.append(TextReplacement(rangeUTF16: word.rangeUTF16, replacement: translated))
                    }
                } catch {
                    logDecision("WARNING: Unknown-language translation failed for '\(word.word)'.")
                }
            }
        }

        guard !replacements.isEmpty else {
            return nil
        }

        let updated = applyReplacements(to: sentenceSelection.sentence, replacements: replacements)
        return TextReplacement(rangeUTF16: sentenceSelection.rangeUTF16, replacement: updated)
    }

    /// Emits a decision log message when a logger is configured.
    private func logDecision(_ message: String) {
        decisionLogger?(message)
    }

    /// Restores diacritics for supported languages when the text appears to lack them.
    private func restoreDiacriticsIfNeeded(for sentence: String, from: Language) -> String? {
        guard let diacriticRestorer else {
            return nil
        }

        if from != .auto {
            guard let restored = diacriticRestorer.restore(sentence, language: from) else {
                return nil
            }
            logDecision("INFO: Diacritic restoration applied for \(from.code).")
            return restored
        }

        let detected = languageIdentifier?.dominantLanguage(for: sentence)
        let candidates = restorationCandidates(detected: detected)
        guard !candidates.isEmpty else {
            logDecision("INFO: Diacritic restoration skipped because language is undetermined.")
            return nil
        }
        guard let result = diacriticRestorer.restore(sentence, candidates: candidates) else {
            return nil
        }
        logDecision("INFO: Diacritic restoration applied for \(result.language.code).")
        return result.text
    }

    /// Returns candidate languages for diacritic restoration when auto-detect is used.
    private func restorationCandidates(detected: Language?) -> [Language] {
        var candidates: [Language] = []
        if let detected {
            candidates.append(detected)
        }
        for code in DiacriticRestorer.supportedLanguageCodes {
            if candidates.contains(where: { $0.code == code }) {
                continue
            }
            candidates.append(Language(code: code))
        }
        return candidates
    }

    /// Applies a set of replacements to a sentence, using ranges relative to the sentence.
    private func applyReplacements(to sentence: String, replacements: [TextReplacement]) -> String {
        let mutable = NSMutableString(string: sentence)
        let sorted = replacements.sorted { $0.rangeUTF16.location > $1.rangeUTF16.location }
        for replacement in sorted {
            mutable.replaceCharacters(in: replacement.rangeUTF16, with: replacement.replacement)
        }
        return mutable as String
    }

    /// Returns true when a translated token is sufficiently different from the original.
    private func shouldApplyTranslation(original: String, translated: String) -> Bool {
        let normalizedOriginal = normalizeToken(original)
        let normalizedTranslated = normalizeToken(translated)
        guard !normalizedOriginal.isEmpty, normalizedOriginal != normalizedTranslated else {
            return false
        }
        let similarity = normalizedSimilarity(normalizedOriginal, normalizedTranslated)
        return similarity < 0.9
    }

    /// Normalizes a token for lightweight similarity checks.
    private func normalizeToken(_ token: String) -> String {
        token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Computes a similarity score in the range 0...1 based on edit distance.
    private func normalizedSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(lhs)
        let b = Array(rhs)
        let distance = editDistance(a, b)
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else {
            return 1.0
        }
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Computes the edit distance between two character arrays.
    private func editDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for (i, lhsChar) in lhs.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhs.enumerated() {
                let cost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + cost
                )
            }
            previous = current
        }
        return previous[rhs.count]
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
