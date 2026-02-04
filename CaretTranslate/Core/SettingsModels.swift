import Foundation

public enum ShortcutMode: String, Codable, CaseIterable, Sendable {
    case doubleTap
    case hotkey
}

public struct HotkeyModifier: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = HotkeyModifier(rawValue: 1 << 0)
    public static let option = HotkeyModifier(rawValue: 1 << 1)
    public static let control = HotkeyModifier(rawValue: 1 << 2)
    public static let shift = HotkeyModifier(rawValue: 1 << 3)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct HotkeyBinding: Codable, Equatable, Sendable {
    public let key: String
    public let modifiers: HotkeyModifier

    public init(key: String, modifiers: HotkeyModifier) {
        self.key = key
        self.modifiers = modifiers
    }

    public static let `default` = HotkeyBinding(key: "t", modifiers: [.command, .shift])
}
