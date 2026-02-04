import Foundation

/// Defines the asynchronous translation interface used by the app.
public protocol Translator: Sendable {
    /// Translates the supplied text from the source language into the target language.
    func translate(_ text: String, from: Language, to: Language) async throws -> String?
}
