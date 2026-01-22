import ApplicationServices
import CaretTranslateCore

struct AccessibilityTextSnapshot: Equatable {
    let snapshot: TextSnapshot
    let offsetUTF16: Int
    let isSecureField: Bool
}

final class AccessibilityTextClient {
    private let contextReader: ContextTextReader

    init(contextReader: ContextTextReader = ContextTextReader()) {
        self.contextReader = contextReader
    }

    func captureSnapshot() throws -> AccessibilityTextSnapshot {
        let element = try focusedElement()
        let role = readStringAttribute(kAXRoleAttribute as CFString, from: element)
        let subrole = readStringAttribute(kAXSubroleAttribute as CFString, from: element)
        let isSecureField = SecureFieldDetector.isSecure(role: role, subrole: subrole)
        let selectionRange = try readSelectionRange(from: element)
        let caret = selectionRange.location

        do {
            let text = try readValue(from: element)
            let snapshot = TextSnapshot(text: text, caretUTF16: caret)
            return AccessibilityTextSnapshot(snapshot: snapshot, offsetUTF16: 0, isSecureField: isSecureField)
        } catch {
            let totalLength = readTextLength(from: element)
            if let context = contextReader.read(
                caretUTF16: caret,
                totalLength: totalLength,
                readRange: { range in
                    try? readStringForRange(range, from: element)
                }
            ) {
                let snapshot = TextSnapshot(text: context.text, caretUTF16: context.caretUTF16)
                return AccessibilityTextSnapshot(
                    snapshot: snapshot,
                    offsetUTF16: context.rangeUTF16.location,
                    isSecureField: isSecureField
                )
            }
            throw error
        }
    }

    func replace(rangeUTF16: NSRange, with text: String) throws {
        let element = try focusedElement()
        var cfRange = CFRange(location: rangeUTF16.location, length: rangeUTF16.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            throw AccessibilityTextError.invalidRange
        }

        let rangeResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
        guard rangeResult == .success else {
            throw AccessibilityTextError.cannotSetSelection
        }

        let textResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        guard textResult == .success else {
            throw AccessibilityTextError.cannotSetText
        }
    }

    private func focusedElement() throws -> AXUIElement {
        let systemElement = AXUIElementCreateSystemWide()
        var element: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &element
        )
        guard result == .success, let element else {
            throw AccessibilityTextError.noFocusedElement
        }
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            throw AccessibilityTextError.noFocusedElement
        }
        return element as! AXUIElement
    }

    private func readValue(from element: AXUIElement) throws -> String {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )
        guard result == .success else {
            throw AccessibilityTextError.cannotReadValue
        }
        if let text = value as? String {
            return text
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        throw AccessibilityTextError.missingValue
    }

    private func readSelectionRange(from element: AXUIElement) throws -> NSRange {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard result == .success else {
            throw AccessibilityTextError.cannotReadSelection
        }
        guard let rangeValue else {
            throw AccessibilityTextError.missingSelection
        }
        guard CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            throw AccessibilityTextError.missingSelection
        }
        let axValue = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            throw AccessibilityTextError.missingSelection
        }
        guard range.location != kCFNotFound else {
            throw AccessibilityTextError.missingSelection
        }
        return NSRange(location: range.location, length: range.length)
    }

    private func readTextLength(from element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXNumberOfCharactersAttribute as CFString,
            &value
        )
        guard result == .success else {
            return nil
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func readStringForRange(_ range: NSRange, from element: AXUIElement) throws -> String {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            throw AccessibilityTextError.invalidRange
        }

        if let text = readStringParameterized(
            attribute: kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue: rangeValue,
            element: element
        ) {
            return text
        }

        if let text = readStringParameterized(
            attribute: kAXAttributedStringForRangeParameterizedAttribute as CFString,
            rangeValue: rangeValue,
            element: element
        ) {
            return text
        }

        throw AccessibilityTextError.cannotReadContext
    }

    private func readStringParameterized(
        attribute: CFString,
        rangeValue: AXValue,
        element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            attribute,
            rangeValue,
            &value
        )
        guard result == .success, let value else {
            return nil
        }
        if let text = value as? String {
            return text
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        return nil
    }

    private func readStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        )
        guard result == .success else {
            return nil
        }
        return value as? String
    }
}

enum AccessibilityTextError: Error {
    case noFocusedElement
    case cannotReadValue
    case missingValue
    case cannotReadSelection
    case missingSelection
    case invalidRange
    case cannotSetSelection
    case cannotSetText
    case cannotReadContext
}
