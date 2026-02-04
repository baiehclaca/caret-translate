import Foundation

public protocol ContextualFixer {
    func fix(_ context: ContextualFixerContext) async throws -> String?
}

public struct ContextualFixerContext: Sendable, Equatable {
    public let sourceSentence: String
    public let sourceWordRangeUTF16: NSRange
    public let translatedSentence: String
    public let sourceLanguage: Language
    public let targetLanguage: Language

    public init(
        sourceSentence: String,
        sourceWordRangeUTF16: NSRange,
        translatedSentence: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) {
        self.sourceSentence = sourceSentence
        self.sourceWordRangeUTF16 = sourceWordRangeUTF16
        self.translatedSentence = translatedSentence
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    public func taggedSourceSentence(tag: String = "source") -> String? {
        let nsSentence = sourceSentence as NSString
        guard sourceWordRangeUTF16.location >= 0,
              sourceWordRangeUTF16.length >= 0,
              sourceWordRangeUTF16.location + sourceWordRangeUTF16.length <= nsSentence.length else {
            return nil
        }

        let prefix = nsSentence.substring(to: sourceWordRangeUTF16.location)
        let word = nsSentence.substring(with: sourceWordRangeUTF16)
        let suffix = nsSentence.substring(from: sourceWordRangeUTF16.location + sourceWordRangeUTF16.length)
        return "\(prefix)<\(tag)>\(word)</\(tag)>\(suffix)"
    }
}
