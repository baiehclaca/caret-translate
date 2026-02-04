import AppKit

@MainActor
final class DebugWindowController: NSWindowController {
    private let store: DebugLogStore
    private let textView = NSTextView()
    private var observerToken: UUID?

    init(store: DebugLogStore = .shared) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CaretTranslate Debug Log"
        super.init(window: window)
        setupContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let observerToken {
            Task { @MainActor [store] in
                store.removeObserver(observerToken)
            }
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        updateText()
    }

    private func setupContent() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        window?.contentView = scrollView

        observerToken = store.addObserver { [weak self] _ in
            self?.updateText()
        }
    }

    private func updateText() {
        textView.string = DebugLogFormatter.format(store.entries)
        let end = NSRange(location: textView.string.utf16.count, length: 0)
        DispatchQueue.main.async { [weak textView] in
            guard let textView = textView else { return }
            textView.scrollRangeToVisible(end)
        }
    }
}

enum DebugLogFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func format(_ entries: [DebugLogEntry]) -> String {
        entries.map { entry in
            let time = formatter.string(from: entry.timestamp)
            return "[\(time)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
