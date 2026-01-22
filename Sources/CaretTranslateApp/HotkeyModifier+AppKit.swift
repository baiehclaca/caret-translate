import AppKit
import CaretTranslateCore

extension HotkeyModifier {
    func toModifierFlags() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) {
            flags.insert(.command)
        }
        if contains(.option) {
            flags.insert(.option)
        }
        if contains(.control) {
            flags.insert(.control)
        }
        if contains(.shift) {
            flags.insert(.shift)
        }
        return flags
    }
}
