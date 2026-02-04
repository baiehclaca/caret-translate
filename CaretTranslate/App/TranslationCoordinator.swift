import AppKit
import Foundation

@available(macOS 15.0, *)
@MainActor
final class TranslationCoordinator {
    private let settings: SettingsStore
    private let textClient: AccessibilityTextClient
    private let historyStore: TranslationHistoryStore
    private let previewController = TranslationPreviewWindowController()
    private let sentenceTranslator: Translator
    private let wordTranslator: Translator
    private let languageIdentifier: WordLanguageIdentifying?
    private let diacriticRestorer: DiacriticRestorer
    private let nllbTranslator: NLLBTranslator
    private let warmupController: TranslationWarmupController
    private var prefetchTask: Task<PreparedTranslation?, Error>?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.textClient = AccessibilityTextClient()
        self.historyStore = TranslationHistoryStore(settings: settings)

        let appleTranslator = AppleTranslator(logger: DebugLogger.log)
        self.nllbTranslator = NLLBTranslator(logger: DebugLogger.log)
        let languageIdentifier = NaturalLanguageWordLanguageIdentifier(logger: DebugLogger.log)
        self.diacriticRestorer = DiacriticRestorer()

        let routingTranslator = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator,
            languageIdentifier: languageIdentifier,
            logger: DebugLogger.log
        )

        self.sentenceTranslator = routingTranslator
        self.wordTranslator = routingTranslator
        self.languageIdentifier = languageIdentifier
        self.warmupController = TranslationWarmupController(
            translator: routingTranslator,
            logger: DebugLogger.log
        )
    }

    func shutdown() {
        Task {
            await nllbTranslator.shutdown()
        }
    }

    /// Ensures the persisted source/target language selections are valid and supported.
    func normalizeLanguageSelectionIfNeeded() {
        let supportedCodes = Set(SupportedLanguages.all.map { $0.code.lowercased() })
        let autoCode = LanguageOption.auto.code

        let currentSource = settings.sourceLanguage.code.lowercased()
        let currentTarget = settings.targetLanguage.code.lowercased()

        let normalizedSource = normalizeLanguageCode(
            currentSource,
            supportedCodes: supportedCodes,
            fallback: autoCode,
            allowAuto: true
        )
        let normalizedTarget = normalizeLanguageCode(
            currentTarget,
            supportedCodes: supportedCodes,
            fallback: "en",
            allowAuto: false
        )

        var didChange = false

        if normalizedSource != currentSource {
            settings.sourceLanguage = Language(code: normalizedSource)
            didChange = true
        }
        if normalizedTarget != currentTarget {
            settings.targetLanguage = Language(code: normalizedTarget)
            didChange = true
        }

        if didChange {
            DebugLogger.log("WARNING: Language settings were invalid and have been reset.")
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Performs a silent warm-up translation on app launch to reduce first-use latency.
    func warmUpTranslationOnLaunch() {
        warmupController.warmUp(from: settings.sourceLanguage, to: settings.targetLanguage)
    }

    func translateNearestWord() {
        Task { @MainActor in
            do {
                DebugLogger.log("Translate triggered")
                warmupController.cancel()
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
        warmupController.cancel()
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
        if capture.isSecureField {
            DebugLogger.log("Translation blocked: secure field")
            return nil
        }
        DebugLogger.log("Snapshot captured: length=\(capture.snapshot.text.utf16.count) caret=\(capture.snapshot.caretUTF16) offset=\(capture.offsetUTF16)")
        let service = TranslationService(
            sentenceSelector: SentenceSelector(),
            sentenceTranslator: sentenceTranslator,
            wordSelector: WordSelector(maxDistance: 1),
            wordTranslator: wordTranslator,
            languageIdentifier: languageIdentifier,
            diacriticRestorer: diacriticRestorer,
            decisionLogger: DebugLogger.log
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

    /// Normalizes a language code to a supported value or fallback.
    private func normalizeLanguageCode(
        _ code: String,
        supportedCodes: Set<String>,
        fallback: String,
        allowAuto: Bool
    ) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }
        let normalized = trimmed.lowercased()
        if !allowAuto && normalized == LanguageOption.auto.code {
            return fallback
        }
        guard supportedCodes.contains(normalized) else {
            return fallback
        }
        return normalized
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
