import Foundation

/// Coordinates a silent warm-up translation to reduce first-use latency.
@available(macOS 15.0, *)
@MainActor
public final class TranslationWarmupController {
    private let translator: Translator
    private let warmupText: String
    private let logger: (@Sendable (String) -> Void)?
    private var task: Task<Void, Never>?

    /// Creates a warm-up controller for a specific translator and sample text.
    public init(
        translator: Translator,
        warmupText: String = "Hello",
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.translator = translator
        self.warmupText = warmupText
        self.logger = logger
    }

    /// Starts or restarts a warm-up translation for the given language pair.
    public func warmUp(from: Language, to: Language) {
        cancel()

        let trimmed = warmupText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger?("WARNING: Warmup skipped because warmup text is empty.")
            return
        }
        guard !to.code.isEmpty else {
            logger?("WARNING: Warmup skipped because target language is missing.")
            return
        }

        task = Task { @MainActor in
            logger?("INFO: Warmup translation started (\(from.code) -> \(to.code)).")
            do {
                _ = try await translator.translate(trimmed, from: from, to: to)
                logger?("INFO: Warmup translation completed.")
            } catch is CancellationError {
                logger?("INFO: Warmup translation cancelled.")
            } catch {
                if let appleError = error as? AppleTranslationError, case .cancelled = appleError {
                    logger?("INFO: Warmup translation cancelled.")
                    return
                }
                logger?("WARNING: Warmup translation failed: \(error).")
            }
        }
    }

    /// Cancels any in-flight warm-up translation.
    public func cancel() {
        task?.cancel()
        task = nil
    }
}
