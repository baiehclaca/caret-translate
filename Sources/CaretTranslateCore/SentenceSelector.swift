import Foundation

public struct SentenceSelection: Equatable {
    public let sentence: String
    public let rangeUTF16: NSRange

    public init(sentence: String, rangeUTF16: NSRange) {
        self.sentence = sentence
        self.rangeUTF16 = rangeUTF16
    }
}

public struct SentenceSelector {
    private let terminators: CharacterSet
    private let whitespace = CharacterSet.whitespacesAndNewlines

    public init(terminators: CharacterSet = SentenceSelector.defaultTerminators) {
        self.terminators = terminators
    }

    public func selectSentence(in snapshot: TextSnapshot) -> SentenceSelection? {
        let text = snapshot.text as NSString
        let length = text.length
        guard length > 0 else {
            return nil
        }

        let caret = max(0, min(snapshot.caretUTF16, length))
        var start = 0
        var index = max(0, caret - 1)
        while index >= 0 {
            if isTerminator(text.character(at: index)) {
                start = index + 1
                break
            }
            index -= 1
        }

        var end = length
        index = caret
        while index < length {
            if isTerminator(text.character(at: index)) {
                end = index + 1
                break
            }
            index += 1
        }

        while start < end, isWhitespace(text.character(at: start)) {
            start += 1
        }
        while end > start, isWhitespace(text.character(at: end - 1)) {
            end -= 1
        }

        guard end > start else {
            return nil
        }

        let range = NSRange(location: start, length: end - start)
        let sentence = text.substring(with: range)
        return SentenceSelection(sentence: sentence, rangeUTF16: range)
    }

    private func isTerminator(_ value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(value) else {
            return false
        }
        return terminators.contains(scalar)
    }

    private func isWhitespace(_ value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(value) else {
            return false
        }
        return whitespace.contains(scalar)
    }

    public static let defaultTerminators: CharacterSet = {
        var set = CharacterSet(charactersIn: ".!?")
        set.formUnion(.newlines)
        return set
    }()
}
