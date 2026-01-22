import Foundation

public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let control = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)
}

public struct KeyPress: Equatable, Sendable {
    public let key: String
    public let modifiers: KeyModifiers
    public let isRepeat: Bool
    public let timestamp: TimeInterval

    public init(key: String, modifiers: KeyModifiers, isRepeat: Bool, timestamp: TimeInterval) {
        self.key = key
        self.modifiers = modifiers
        self.isRepeat = isRepeat
        self.timestamp = timestamp
    }
}

public enum DoubleTapDecision: Equatable, Sendable {
    case ignored
    case pending
    case triggered
}

public final class DoubleTapDetector {
    private let threshold: TimeInterval
    private var lastTapTime: TimeInterval?

    public init(threshold: TimeInterval = 0.3) {
        self.threshold = threshold
    }

    public func registerTap(at time: TimeInterval) -> Bool {
        guard let lastTapTime else {
            self.lastTapTime = time
            return false
        }

        let interval = time - lastTapTime
        if interval >= 0, interval <= threshold {
            self.lastTapTime = nil
            return true
        }

        self.lastTapTime = time
        return false
    }

    public func reset() {
        lastTapTime = nil
    }
}

public final class DoubleTapShortcutHandler {
    private let detector: DoubleTapDetector
    private let targetKey: String
    public let threshold: TimeInterval

    public init(targetKey: String = "\t", threshold: TimeInterval = 0.3) {
        self.targetKey = targetKey
        self.threshold = threshold
        self.detector = DoubleTapDetector(threshold: threshold)
    }

    public func register(keyPress: KeyPress) -> DoubleTapDecision {
        guard !keyPress.isRepeat else {
            return .ignored
        }
        guard keyPress.modifiers.isEmpty else {
            detector.reset()
            return .ignored
        }
        guard keyPress.key == targetKey else {
            detector.reset()
            return .ignored
        }
        return detector.registerTap(at: keyPress.timestamp) ? .triggered : .pending
    }

    public func reset() {
        detector.reset()
    }
}
