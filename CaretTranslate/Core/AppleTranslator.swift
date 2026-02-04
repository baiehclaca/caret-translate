import Foundation
import SwiftUI
@preconcurrency import Translation

/// Errors emitted by the Apple Translation integration.
@available(macOS 15.0, *)
public enum AppleTranslationError: Error {
    /// Indicates a translation request is already in progress.
    case busy
    /// Indicates a translation request timed out.
    case timeout
    /// Indicates a translation request was cancelled.
    case cancelled
}

/// Actor that manages translations using Apple's Translation framework.
/// Requires macOS 15.0+ (Sequoia) for the Translation API.
@available(macOS 15.0, *)
@MainActor
public final class AppleTranslationManager: ObservableObject {
    /// A translation request emitted for the worker to process.
    public struct TranslationRequest: Sendable {
        public let id: UUID
        public let text: String
    }

    public static let shared = AppleTranslationManager()

    @Published public var pendingText: String?
    @Published public var sourceLanguage: Locale.Language?
    @Published public var targetLanguage: Locale.Language?
    @Published public var result: String?
    @Published public var error: Error?

    private var continuation: CheckedContinuation<String?, Error>?
    private var activeRequestId: UUID?
    private var timeoutTask: Task<Void, Never>?
    private var requestContinuation: AsyncStream<TranslationRequest>.Continuation?
    private let timeoutSeconds: UInt64 = 30

    private init() {}

    /// Returns an async stream of translation requests.
    public func requestStream() -> AsyncStream<TranslationRequest> {
        AsyncStream { continuation in
            requestContinuation = continuation
        }
    }

    /// Translates text using the Translation framework, enforcing a single in-flight request.
    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        guard continuation == nil else {
            throw AppleTranslationError.busy
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let requestId = UUID()
        activeRequestId = requestId
        pendingText = text
        sourceLanguage = from == .auto ? nil : Locale.Language(identifier: from.code)
        targetLanguage = Locale.Language(identifier: to.code)
        result = nil
        error = nil

        scheduleTimeout(for: requestId)
        requestContinuation?.yield(TranslationRequest(id: requestId, text: text))

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                self?.fail(with: AppleTranslationError.cancelled)
            }
        })
    }

    /// Completes the current translation request.
    public func complete(with result: String?) {
        self.result = result
        guard let continuation else {
            return
        }
        clearPendingState()
        continuation.resume(returning: result)
    }

    /// Fails the current translation request with an error.
    public func fail(with error: Error) {
        self.error = error
        guard let continuation else {
            return
        }
        clearPendingState()
        continuation.resume(throwing: error)
    }

    /// Clears any in-flight request state.
    private func clearPendingState() {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation = nil
        pendingText = nil
        activeRequestId = nil
    }

    /// Schedules a timeout for the current translation request.
    private func scheduleTimeout(for requestId: UUID) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await Task.sleep(nanoseconds: self.timeoutSeconds * 1_000_000_000)
            } catch {
                return
            }
            await MainActor.run {
                guard self.activeRequestId == requestId,
                      self.continuation != nil else {
                    return
                }
                self.fail(with: AppleTranslationError.timeout)
            }
        }
    }
}

/// SwiftUI view that performs translations using the Translation framework.
/// Embed this view in your app's view hierarchy to enable translations.
@available(macOS 15.0, *)
public struct TranslationWorkerView: View {
    @ObservedObject private var manager = AppleTranslationManager.shared

    public init() {}

    public var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
            .translationTask(configuration) { session in
                let stream = await MainActor.run {
                    manager.requestStream()
                }
                for await request in stream {
                    do {
                        let response = try await session.translate(request.text)
                        await MainActor.run {
                            manager.complete(with: response.targetText)
                        }
                    } catch {
                        await MainActor.run {
                            manager.fail(with: error)
                        }
                    }
                }
            }
    }

    private var configuration: TranslationSession.Configuration? {
        guard let target = manager.targetLanguage else {
            return nil
        }
        return TranslationSession.Configuration(
            source: manager.sourceLanguage,
            target: target
        )
    }

}

/// Translator implementation that uses Apple's Translation framework via SwiftUI.
@available(macOS 15.0, *)
public struct AppleTranslator: Translator {
    private let logger: (@Sendable (String) -> Void)?

    public init(logger: (@Sendable (String) -> Void)? = nil) {
        self.logger = logger
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        let result = try await AppleTranslationManager.shared.translate(text, from: from, to: to)
        if let result {
            logger?("AppleTranslator: '\(text)' -> '\(result)'")
        }
        return result
    }
}
