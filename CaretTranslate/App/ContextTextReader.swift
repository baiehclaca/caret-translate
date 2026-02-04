import Foundation

struct ContextTextReadResult: Equatable {
    let text: String
    let rangeUTF16: NSRange
    let caretUTF16: Int
}

struct ContextTextReader {
    let rangeSizes: [Int]

    init(rangeSizes: [Int] = [400, 200, 100, 50]) {
        self.rangeSizes = rangeSizes
    }

    func read(
        caretUTF16: Int,
        totalLength: Int?,
        readRange: (NSRange) -> String?
    ) -> ContextTextReadResult? {
        for length in rangeSizes where length > 0 {
            let range = Self.contextRange(caretUTF16: caretUTF16, length: length, totalLength: totalLength)
            if let text = readRange(range) {
                let localCaret = max(0, min(caretUTF16 - range.location, text.utf16.count))
                return ContextTextReadResult(text: text, rangeUTF16: range, caretUTF16: localCaret)
            }
        }
        return nil
    }

    static func contextRange(caretUTF16: Int, length: Int, totalLength: Int?) -> NSRange {
        let safeCaret = max(0, caretUTF16)
        guard length > 0 else {
            return NSRange(location: safeCaret, length: 0)
        }
        if let totalLength, totalLength > 0 {
            if length >= totalLength {
                return NSRange(location: 0, length: totalLength)
            }
            var start = max(0, safeCaret - length / 2)
            if start + length > totalLength {
                start = max(0, totalLength - length)
            }
            return NSRange(location: start, length: length)
        }
        let start = max(0, safeCaret - length / 2)
        return NSRange(location: start, length: length)
    }
}
