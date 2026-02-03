import Foundation

/// A translator that routes requests to Apple Translation or NLLB based on language support.
public struct RoutingTranslator: Translator {
    private let appleTranslator: Translator
    private let nllbTranslator: Translator
    private let logger: (@Sendable (String) -> Void)?

    public init(
        appleTranslator: Translator,
        nllbTranslator: Translator,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.appleTranslator = appleTranslator
        self.nllbTranslator = nllbTranslator
        self.logger = logger
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        if shouldUseApple(from: from, to: to) {
            logger?("RoutingTranslator: Using Apple for \(from.code) -> \(to.code)")
            return try await appleTranslator.translate(text, from: from, to: to)
        } else {
            logger?("RoutingTranslator: Using NLLB for \(from.code) -> \(to.code)")
            return try await nllbTranslator.translate(text, from: from, to: to)
        }
    }

    /// Returns true if Apple Translation supports this language pair.
    private func shouldUseApple(from: Language, to: Language) -> Bool {
        let appleSupported = NLLBLanguageCodes.appleSupported

        // For auto-detect, check if target is Apple supported
        if from == .auto {
            return appleSupported.contains(to.code.lowercased())
        }

        // Both source and target must be Apple supported
        return appleSupported.contains(from.code.lowercased()) &&
               appleSupported.contains(to.code.lowercased())
    }
}
