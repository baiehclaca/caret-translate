import Foundation
import CaretTranslateCore

extension ShortcutMode {
    var label: String {
        switch self {
        case .doubleTap:
            return "Double-tap Tab"
        case .hotkey:
            return "Custom Hotkey"
        }
    }
}

extension TranslationFormality {
    var label: String {
        switch self {
        case .default:
            return "Default"
        case .more:
            return "More Formal"
        case .less:
            return "Less Formal"
        }
    }
}

extension PerformanceMode {
    var label: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .quality:
            return "Quality"
        }
    }
}
