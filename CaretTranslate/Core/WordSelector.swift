import Foundation

public struct WordSelection: Equatable {
    public let word: String
    public let rangeUTF16: NSRange
}

public struct WordSelector {
    private let maxDistance: Int

    public init(maxDistance: Int) {
        self.maxDistance = maxDistance
    }

    /// Returns all word selections found in the supplied text.
    public func selectWords(in text: String) -> [WordSelection] {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else {
            return []
        }

        var selections: [WordSelection] = []
        var index = 0
        while index < length {
            if isWordChar(nsText.character(at: index)) {
                let start = index
                var end = index + 1
                while end < length, isWordChar(nsText.character(at: end)) {
                    end += 1
                }
                let range = NSRange(location: start, length: end - start)
                let word = nsText.substring(with: range)
                selections.append(WordSelection(word: word, rangeUTF16: range))
                index = end
            } else {
                index += 1
            }
        }
        return selections
    }

    public func selectNearestWord(in snapshot: TextSnapshot) -> WordSelection? {
        let text = snapshot.text as NSString
        let length = text.length
        guard length > 0 else {
            return nil
        }

        let caret = max(0, min(snapshot.caretUTF16, length))
        let left = nearestWordIndexLeft(in: text, caret: caret)
        let right = nearestWordIndexRight(in: text, caret: caret)
        if left == nil && right == nil {
            return nil
        }
        if let left, right == nil {
            return selection(in: text, around: left)
        }
        if let right, left == nil {
            return selection(in: text, around: right)
        }

        guard let left, let right else {
            return nil
        }
        let leftDistance = caret - left
        let rightDistance = right - caret
        let chosen = leftDistance <= rightDistance ? left : right
        return selection(in: text, around: chosen)
    }

    private func selection(in text: NSString, around index: Int) -> WordSelection? {
        let length = text.length
        guard index >= 0 && index < length else {
            return nil
        }
        guard isWordChar(text.character(at: index)) else {
            return nil
        }

        var start = index
        var end = index + 1

        while start > 0 && isWordChar(text.character(at: start - 1)) {
            start -= 1
        }
        while end < length && isWordChar(text.character(at: end)) {
            end += 1
        }

        let range = NSRange(location: start, length: end - start)
        let word = text.substring(with: range)
        return WordSelection(word: word, rangeUTF16: range)
    }

    private func nearestWordIndexLeft(in text: NSString, caret: Int) -> Int? {
        guard maxDistance >= 0 else {
            return nil
        }

        var distance = 0
        var index = caret - 1
        while index >= 0 && distance <= maxDistance {
            if isWordChar(text.character(at: index)) {
                return index
            }
            index -= 1
            distance += 1
        }
        return nil
    }

    private func nearestWordIndexRight(in text: NSString, caret: Int) -> Int? {
        guard maxDistance >= 0 else {
            return nil
        }

        var distance = 0
        var index = caret
        while index < text.length && distance <= maxDistance {
            if isWordChar(text.character(at: index)) {
                return index
            }
            index += 1
            distance += 1
        }
        return nil
    }

    private func isWordChar(_ value: unichar) -> Bool {
        if value == 0x27 {
            return true
        }
        guard let scalar = UnicodeScalar(value) else {
            return false
        }
        if CharacterSet.letters.contains(scalar) {
            return true
        }
        if CharacterSet.decimalDigits.contains(scalar) {
            return true
        }
        return false
    }
}
