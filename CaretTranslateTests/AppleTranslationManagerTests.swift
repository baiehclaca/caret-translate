import XCTest
@testable import CaretTranslate

@available(macOS 15.0, *)
final class AppleTranslationManagerTests: XCTestCase {
    /// Ensures the manager resumes a translation request when completion is provided.
    func testTranslateCompletesWhenManagerCompletes() async throws {
        let manager = await MainActor.run { AppleTranslationManager.shared }
        let translationTask = Task { @MainActor in
            try await manager.translate("hello", from: Language(code: "en"), to: Language(code: "es"))
        }

        await Task.yield()
        await MainActor.run {
            manager.complete(with: "hola")
        }

        let result = try await translationTask.value
        XCTAssertEqual(result, "hola")
        let pendingText = await MainActor.run { manager.pendingText }
        XCTAssertNil(pendingText)
    }
}
