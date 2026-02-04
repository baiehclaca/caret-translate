import Foundation

public struct TextReplacement: Equatable, Sendable {
    public let rangeUTF16: NSRange
    public let replacement: String

    public init(rangeUTF16: NSRange, replacement: String) {
        self.rangeUTF16 = rangeUTF16
        self.replacement = replacement
    }

    public func applying(to text: String) -> String? {
        let nsText = text as NSString
        guard rangeUTF16.location >= 0,
              rangeUTF16.length >= 0,
              rangeUTF16.location + rangeUTF16.length <= nsText.length else {
            return nil
        }
        return nsText.replacingCharacters(in: rangeUTF16, with: replacement)
    }
}
