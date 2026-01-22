import AppKit
import ApplicationServices
import CaretTranslateCore

final class DoubleTabMonitor {
    private let handler: DoubleTapShortcutHandler
    private let trigger: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pendingWorkItem: DispatchWorkItem?
    private var suppressedKeyUpCount = 0
    private let targetKeyCode: CGKeyCode = 48
    private let syntheticEventMarker: Int64 = 0x43545442

    init(handler: DoubleTapShortcutHandler = DoubleTapShortcutHandler(), trigger: @escaping () -> Void) {
        self.handler = handler
        self.trigger = trigger
    }

    @discardableResult
    func start() -> Bool {
        stop()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<DoubleTabMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handleTap(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        suppressedKeyUpCount = 0
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            if keyCode == targetKeyCode, suppressedKeyUpCount > 0 {
                suppressedKeyUpCount -= 1
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let modifiers = KeyModifiers(event.flags)
        let key = keyCode == targetKeyCode ? "\t" : ""
        let keyPress = KeyPress(
            key: key,
            modifiers: modifiers,
            isRepeat: isRepeat,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        let decision = handler.register(keyPress: keyPress)

        if keyCode != targetKeyCode {
            if pendingWorkItem != nil {
                flushPendingTab()
            }
            return Unmanaged.passUnretained(event)
        }

        switch decision {
        case .ignored:
            return Unmanaged.passUnretained(event)
        case .pending:
            suppressedKeyUpCount += 1
            schedulePendingTab()
            return nil
        case .triggered:
            suppressedKeyUpCount += 1
            cancelPendingTab()
            trigger()
            return nil
        }
    }

    private func schedulePendingTab() {
        cancelPendingTab()
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingWorkItem = nil
            self?.postTabKeyPress()
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + handler.threshold, execute: workItem)
    }

    private func cancelPendingTab() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private func flushPendingTab() {
        cancelPendingTab()
        postTabKeyPress()
    }

    private func postTabKeyPress() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: targetKeyCode, keyDown: true) {
            keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
            keyDown.post(tap: .cgSessionEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: targetKeyCode, keyDown: false) {
            keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
            keyUp.post(tap: .cgSessionEventTap)
        }
    }
}

private extension KeyModifiers {
    init(_ flags: CGEventFlags) {
        var result: KeyModifiers = []
        if flags.contains(.maskCommand) {
            result.insert(.command)
        }
        if flags.contains(.maskAlternate) {
            result.insert(.option)
        }
        if flags.contains(.maskControl) {
            result.insert(.control)
        }
        if flags.contains(.maskShift) {
            result.insert(.shift)
        }
        self = result
    }
}
