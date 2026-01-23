import Foundation
import CaretTranslateCore

@MainActor
final class CachedTranslator: Translator, @unchecked Sendable {
    private let translator: Translator
    private let cache: TranslationCacheStore
    private let formalityProvider: () -> TranslationFormality
    private var inflight: [String: [CheckedContinuation<String?, Error>]] = [:]

    init(
        translator: Translator,
        cache: TranslationCacheStore,
        formalityProvider: @escaping () -> TranslationFormality
    ) {
        self.translator = translator
        self.cache = cache
        self.formalityProvider = formalityProvider
    }

    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        let formality = formalityProvider()
        let key = TranslationCacheKey(
            text: text,
            source: from,
            target: to,
            formality: formality
        ).digest

        if let cached = await cache.lookup(key: key) {
            DebugLogger.log("Cache hit for translation")
            return cached
        }

        do {
            let value = try await resolveTranslation(
                text: text,
                from: from,
                to: to,
                key: key
            )
            if let value {
                await cache.insert(value, for: key)
            }
            return value
        } catch {
            throw error
        }
    }

    private func resolveTranslation(
        text: String,
        from: Language,
        to: Language,
        key: String
    ) async throws -> String? {
        if inflight[key] != nil {
            return try await withCheckedThrowingContinuation { continuation in
                inflight[key, default: []].append(continuation)
            }
        }
        inflight[key] = []

        do {
            let value = try await translator.translate(text, from: from, to: to)
            let waiters = drainWaiters(for: key)
            for continuation in waiters {
                continuation.resume(returning: value)
            }
            return value
        } catch {
            let waiters = drainWaiters(for: key)
            for continuation in waiters {
                continuation.resume(throwing: error)
            }
            throw error
        }
    }

    private func drainWaiters(for key: String) -> [CheckedContinuation<String?, Error>] {
        return inflight.removeValue(forKey: key) ?? []
    }
}
