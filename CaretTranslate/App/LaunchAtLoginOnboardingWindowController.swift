import AppKit
import SwiftUI

/// Hosts the welcome/onboarding SwiftUI view in a window.
@MainActor
final class LaunchAtLoginOnboardingWindowController {
    private var windowController: NSWindowController?

    /// Shows the onboarding window, creating it on first use.
    func show(
        initiallyEnabled: Bool,
        onComplete: @escaping (Bool, String, String, ShortcutMode) -> Void
    ) {
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = LaunchAtLoginOnboardingView(
            initiallyEnabled: initiallyEnabled,
            onComplete: onComplete,
            openSettings: openLoginItemsSettings
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to CaretTranslate"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes and releases the onboarding window if it exists.
    func close() {
        windowController?.close()
        windowController = nil
    }

    /// Opens System Settings to the Login Items page when available.
    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
