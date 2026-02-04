import XCTest
@testable import CaretTranslate

@available(macOS 15.0, *)
final class TranslationWarmupControllerTests: XCTestCase {

    /// Ensures a warm-up translation calls into the translator.
    func testWarmUpInvokesTranslator() async {
        let expectation = expectation(description: "translate called")
        let translator = SpyTranslator { _, _, _ in
            expectation.fulfill()
        }
        let controller = TranslationWarmupController(translator: translator, warmupText: "Hello")

        await MainActor.run {
            controller.warmUp(from: Language(code: "en"), to: Language(code: "es"))
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    /// Ensures an empty warm-up string prevents any translation call.
    func testWarmUpSkipsEmptyText() async {
        let expectation = expectation(description: "translate should not be called")
        expectation.isInverted = true
        let translator = SpyTranslator { _, _, _ in
            expectation.fulfill()
        }
        let controller = TranslationWarmupController(translator: translator, warmupText: "   ")

        await MainActor.run {
            controller.warmUp(from: Language(code: "en"), to: Language(code: "es"))
        }

        await fulfillment(of: [expectation], timeout: 0.2)
    }

    /// Ensures cancelling a warm-up request cancels the in-flight translation task.
    func testWarmUpCancelsInFlightTranslation() async {
        let started = expectation(description: "translate started")
        let translator = CancellableTranslator(started: started)
        let controller = TranslationWarmupController(translator: translator, warmupText: "Hello")

        await MainActor.run {
            controller.warmUp(from: Language(code: "en"), to: Language(code: "es"))
        }

        await fulfillment(of: [started], timeout: 1.0)

        await MainActor.run {
            controller.cancel()
        }

        try? await Task.sleep(nanoseconds: 150_000_000)

        let wasCancelled = await MainActor.run { translator.wasCancelled }
        XCTAssertTrue(wasCancelled)
    }
}

@available(macOS 15.0, *)
@MainActor
private final class SpyTranslator: Translator, @unchecked Sendable {
    private let onTranslate: (@Sendable (String, Language, Language) -> Void)?

    /// Creates a spy translator that reports translate calls via a closure.
    init(onTranslate: (@Sendable (String, Language, Language) -> Void)? = nil) {
        self.onTranslate = onTranslate
    }

    /// Records the translation request and returns a fixed result.
    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        onTranslate?(text, from, to)
        return "ok"
    }
}

@available(macOS 15.0, *)
@MainActor
private final class CancellableTranslator: Translator, @unchecked Sendable {
    private let started: XCTestExpectation
    private(set) var wasCancelled = false

    /// Creates a translator that blocks until cancelled, recording cancellation.
    init(started: XCTestExpectation) {
        self.started = started
    }

    /// Suspends until cancelled to exercise warm-up cancellation behavior.
    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        started.fulfill()
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            if Task.isCancelled {
                wasCancelled = true
                throw CancellationError()
            }
            throw error
        }
        return "ok"
    }
}
