import AppKit

final class HotkeyMonitor {
    private let key: String
    private let modifiers: NSEvent.ModifierFlags
    private let handler: () -> Void
    private var monitor: Any?

    init(key: String, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        self.key = key.lowercased()
        self.modifiers = modifiers
        self.handler = handler
    }

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard flags == modifiers else {
            return
        }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters == key else {
            return
        }
        handler()
    }
}
