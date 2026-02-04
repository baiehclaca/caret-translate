import Foundation

/// A translator that routes requests to Apple Translation or NLLB based on language support.
public struct RoutingTranslator: Translator {
    private let appleTranslator: Translator
    private let nllbTranslator: Translator
    private let languageIdentifier: WordLanguageIdentifying?
    private let logger: (@Sendable (String) -> Void)?

    public init(
        appleTranslator: Translator,
        nllbTranslator: Translator,
        languageIdentifier: WordLanguageIdentifying? = nil,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.appleTranslator = appleTranslator
        self.nllbTranslator = nllbTranslator
        self.languageIdentifier = languageIdentifier
        self.logger = logger
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        let detectedLanguage = from == .auto ? languageIdentifier?.dominantLanguage(for: text) : nil
        if shouldUseApple(from: from, to: to, detectedLanguage: detectedLanguage) {
            logger?("RoutingTranslator: Using Apple for \(from.code) -> \(to.code)")
            return try await appleTranslator.translate(text, from: from, to: to)
        }

        let resolvedFrom = detectedLanguage ?? from
        if from == .auto, resolvedFrom == .auto {
            logger?("RoutingTranslator: Auto source unresolved; NLLB may fail for \(to.code).")
        }
        logger?("RoutingTranslator: Using NLLB for \(resolvedFrom.code) -> \(to.code)")
        return try await nllbTranslator.translate(text, from: resolvedFrom, to: to)
    }

    /// Returns true if Apple Translation supports this language pair.
    private func shouldUseApple(from: Language, to: Language, detectedLanguage: Language?) -> Bool {
        let appleSupported = NLLBLanguageCodes.appleSupported

        let targetSupported = appleSupported.contains(to.code.lowercased())

        // For auto-detect, use language identifier to avoid Apple for NLLB-only sources.
        if from == .auto {
            guard targetSupported else {
                return false
            }
            if let detected = detectedLanguage {
                let detectedCode = detected.code.lowercased()
                if NLLBLanguageCodes.isNLLBOnlyLanguage(detectedCode) {
                    logger?("RoutingTranslator: Auto source detected as NLLB-only (\(detectedCode)).")
                    return false
                }
                if appleSupported.contains(detectedCode) {
                    return true
                }
                if NLLBLanguageCodes.isSupported(detectedCode) {
                    logger?("RoutingTranslator: Auto source detected as NLLB-supported (\(detectedCode)).")
                    return false
                }
            }
            return true
        }

        // Both source and target must be Apple supported
        return appleSupported.contains(from.code.lowercased()) && targetSupported
    }
}
