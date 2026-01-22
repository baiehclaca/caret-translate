import Foundation

public struct TextSnapshot: Equatable, Sendable {
    public let text: String
    public let caretUTF16: Int

    public init(text: String, caretUTF16: Int) {
        self.text = text
        self.caretUTF16 = caretUTF16
    }
}
