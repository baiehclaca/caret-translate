import AppKit
import CaretTranslateCore

@MainActor
final class TranslationCoordinator {
    private let settings: SettingsStore
    private let textClient: AccessibilityTextClient
    private let privacyFilter: PrivacyFilter
    private let historyStore: TranslationHistoryStore
    private let dictionaryStore: CustomDictionaryStore
    private let previewController = TranslationPreviewWindowController()
    private let baseDictionary: DictionaryTranslator
    private let wordTranslator: Translator
    private let sentenceTranslator: DeepLTranslator
    private var fixerCache: [PerformanceMode: ContextualFixer] = [:]

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.textClient = AccessibilityTextClient()
        self.privacyFilter = PrivacyFilter(settings: settings)
        self.historyStore = TranslationHistoryStore(settings: settings)
        self.dictionaryStore = CustomDictionaryStore()
        let customDictionary = DynamicDictionaryTranslator { [dictionaryStore] in
            dictionaryStore.entriesMap()
        }
        self.baseDictionary = (try? DictionaryTranslator(resourceName: "dictionary")) ?? DictionaryTranslator(entries: [:])
        self.wordTranslator = FallbackTranslator(primary: customDictionary, fallback: baseDictionary)
        self.sentenceTranslator = DeepLTranslator(formalityProvider: { [settings] in
            settings.translationFormality
        })
    }

    func translateNearestWord() {
        Task { @MainActor in
            do {
                DebugLogger.log("Translate triggered")
                let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                let capture = try textClient.captureSnapshot()
                if !privacyFilter.isAllowed(bundleId: bundleId, isSecureField: capture.isSecureField) {
                    DebugLogger.log("Translation blocked by privacy rules")
                    return
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
                    DebugLogger.log("No replacement returned")
                    return
                }
                let originalText = (capture.snapshot.text as NSString).substring(with: replacement.rangeUTF16)
                if settings.previewEnabled {
                    let confirmed = await previewController.present(
                        original: originalText,
                        replacement: replacement.replacement
                    )
                    if !confirmed {
                        DebugLogger.log("Preview cancelled")
                        return
                    }
                }
                let adjustedRange = NSRange(
                    location: replacement.rangeUTF16.location + capture.offsetUTF16,
                    length: replacement.rangeUTF16.length
                )
                try textClient.replace(rangeUTF16: adjustedRange, with: replacement.replacement)
                DebugLogger.log("Replacement applied: range=\(adjustedRange.location)-\(adjustedRange.length)")
                historyStore.append(
                    TranslationHistoryEntry(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        sourceText: originalText,
                        translatedText: replacement.replacement,
                        sourceLanguage: settings.sourceLanguage.code,
                        targetLanguage: settings.targetLanguage.code,
                        appBundleId: bundleId
                    )
                )
            } catch {
                DebugLogger.log("Translation failed: \(error)")
            }
        }
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
