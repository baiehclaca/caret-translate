import Foundation

public final class DeepLTranslator: Translator, @unchecked Sendable {
    private let apiKeyStore: ApiKeyStore
    private let clientFactory: (String) -> DeepLClient
    private let formalityProvider: () -> TranslationFormality

    public init(
        apiKeyStore: ApiKeyStore = ApiKeyStore(),
        clientFactory: @escaping (String) -> DeepLClient = { DeepLClient(authKey: $0) },
        formalityProvider: @escaping () -> TranslationFormality = { .default }
    ) {
        self.apiKeyStore = apiKeyStore
        self.clientFactory = clientFactory
        self.formalityProvider = formalityProvider
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        guard let key = apiKeyStore.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        let client = clientFactory(key)
        let source = from.code.lowercased() == "auto" ? nil : from.code.uppercased()
        let formality = formalityProvider()
        return try await client.translate(
            text: text,
            source: source,
            target: to.code.uppercased(),
            formality: formality
        )
    }
}

public struct FallbackTranslator: Translator {
    private let primary: Translator
    private let fallback: Translator

    public init(primary: Translator, fallback: Translator) {
        self.primary = primary
        self.fallback = fallback
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        do {
            if let result = try await primary.translate(text, from: from, to: to) {
                return result
            }
        } catch {
            // Fall through to fallback translator.
        }
        return try await fallback.translate(text, from: from, to: to)
    }
}
