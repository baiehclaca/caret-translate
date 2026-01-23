import AppKit
import Foundation
import CaretTranslateCore

@MainActor
final class TranslationCoordinator {
    private let settings: SettingsStore
    private let textClient: AccessibilityTextClient
    private let privacyFilter: PrivacyFilter
    private let historyStore: TranslationHistoryStore
    private let dictionaryStore: CustomDictionaryStore
    private let cacheStore: TranslationCacheStore
    private let previewController = TranslationPreviewWindowController()
    private let baseDictionary: DictionaryTranslator
    private let wordTranslator: Translator
    private let sentenceTranslator: Translator
    private var fixerCache: [PerformanceMode: ContextualFixer] = [:]
    private let deepLSession: URLSession
    private var prefetchTask: Task<PreparedTranslation?, Error>?
    private var warmupStarted = false

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.textClient = AccessibilityTextClient()
        self.privacyFilter = PrivacyFilter(settings: settings)
        self.historyStore = TranslationHistoryStore(settings: settings)
        self.dictionaryStore = CustomDictionaryStore()
        self.cacheStore = TranslationCacheStore.shared
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        self.deepLSession = URLSession(configuration: config)
        let customDictionary = DynamicDictionaryTranslator { [dictionaryStore] in
            dictionaryStore.entriesMap()
        }
        self.baseDictionary = (try? DictionaryTranslator(resourceName: "dictionary")) ?? DictionaryTranslator(entries: [:])
        self.wordTranslator = FallbackTranslator(primary: customDictionary, fallback: baseDictionary)
        let formalityProvider: () -> TranslationFormality = { [settings] in
            settings.translationFormality
        }
        let deepLTranslator = DeepLTranslator(
            clientFactory: { [deepLSession] key in
                DeepLClient(authKey: key, httpClient: deepLSession)
            },
            formalityProvider: formalityProvider
        )
        self.sentenceTranslator = CachedTranslator(
            translator: deepLTranslator,
            cache: cacheStore,
            formalityProvider: formalityProvider
        )
    }

    func translateNearestWord() {
        Task { @MainActor in
            do {
                DebugLogger.log("Translate triggered")
                guard let prepared = try await consumePrefetchOrPrepare() else {
                    DebugLogger.log("No replacement returned")
                    return
                }
                if settings.previewEnabled {
                    let confirmed = await previewController.present(
                        original: prepared.originalText,
                        replacement: prepared.replacement.replacement
                    )
                    if !confirmed {
                        DebugLogger.log("Preview cancelled")
                        return
                    }
                }
                let adjustedRange = NSRange(
                    location: prepared.replacement.rangeUTF16.location + prepared.capture.offsetUTF16,
                    length: prepared.replacement.rangeUTF16.length
                )
                try textClient.replace(rangeUTF16: adjustedRange, with: prepared.replacement.replacement)
                DebugLogger.log("Replacement applied: range=\(adjustedRange.location)-\(adjustedRange.length)")
                historyStore.append(
                    TranslationHistoryEntry(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        sourceText: prepared.originalText,
                        translatedText: prepared.replacement.replacement,
                        sourceLanguage: prepared.sourceLanguage.code,
                        targetLanguage: prepared.targetLanguage.code,
                        appBundleId: prepared.bundleId
                    )
                )
            } catch {
                DebugLogger.log("Translation failed: \(error)")
            }
        }
    }

    func prefetchTranslation() {
        DebugLogger.log("Prefetch requested")
        cancelPrefetch()
        prefetchTask = Task { @MainActor in
            try await prepareTranslation()
        }
    }

    func cancelPrefetch() {
        let hadPrefetch = prefetchTask != nil
        prefetchTask?.cancel()
        prefetchTask = nil
        if hadPrefetch {
            DebugLogger.log("Prefetch cancelled")
        }
    }

    func warmUp() {
        guard !warmupStarted else {
            return
        }
        warmupStarted = true
        guard let key = ApiKeyStore().apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return
        }
        let client = DeepLClient(authKey: key, httpClient: deepLSession)
        Task.detached {
            _ = try? await client.fetchLanguages(type: .source)
        }
    }

    private func consumePrefetchOrPrepare() async throws -> PreparedTranslation? {
        if let task = prefetchTask {
            prefetchTask = nil
            DebugLogger.log("Using prefetched translation")
            return try await task.value
        }
        return try await prepareTranslation()
    }

    private func prepareTranslation() async throws -> PreparedTranslation? {
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let capture = try textClient.captureSnapshot()
        if !privacyFilter.isAllowed(bundleId: bundleId, isSecureField: capture.isSecureField) {
            DebugLogger.log("Translation blocked by privacy rules")
            return nil
        }
        DebugLogger.log("Snapshot captured: length=\(capture.snapshot.text.utf16.count) caret=\(capture.snapshot.caretUTF16) offset=\(capture.offsetUTF16)")
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            contextualFixer: fixerForCurrentMode()
        )
        guard let replacement = try await service.replacement(
            for: capture.snapshot,
            from: settings.sourceLanguage,
            to: settings.targetLanguage
        ) else {
            return nil
        }
        let originalText = (capture.snapshot.text as NSString).substring(with: replacement.rangeUTF16)
        return PreparedTranslation(
            capture: capture,
            replacement: replacement,
            originalText: originalText,
            bundleId: bundleId,
            sourceLanguage: settings.sourceLanguage,
            targetLanguage: settings.targetLanguage
        )
    }

    private func fixerForCurrentMode() -> ContextualFixer? {
        let mode = settings.performanceMode
        if let cached = fixerCache[mode] {
            return cached
        }
        switch mode {
        case .fast:
            return nil
        case .balanced:
            let fixer = QwenContextualFixer(maxNewTokens: 128)
            fixerCache[mode] = fixer
            return fixer
        case .quality:
            let fixer = QwenContextualFixer(maxNewTokens: 256)
            fixerCache[mode] = fixer
            return fixer
        }
    }
}

private struct PreparedTranslation {
    let capture: AccessibilityTextSnapshot
    let replacement: TextReplacement
    let originalText: String
    let bundleId: String?
    let sourceLanguage: Language
    let targetLanguage: Language
}
