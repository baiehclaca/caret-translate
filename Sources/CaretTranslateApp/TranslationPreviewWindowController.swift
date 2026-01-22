import AppKit
import SwiftUI

@MainActor
final class TranslationPreviewWindowController: NSObject, NSWindowDelegate {
    private var windowController: NSWindowController?
    private var continuation: CheckedContinuation<Bool, Never>?

    func present(original: String, replacement: String) async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let rootView = TranslationPreviewView(
                original: original,
                replacement: replacement,
                onConfirm: { [weak self] in
                    self?.finish(result: true)
                },
                onCancel: { [weak self] in
                    self?.finish(result: false)
                }
            )

            let hosting = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Preview Translation"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 520, height: 320))
            window.isReleasedWhenClosed = false
            window.delegate = self

            let controller = NSWindowController(window: window)
            windowController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        finish(result: false)
    }

    private func finish(result: Bool) {
        if let continuation {
            self.continuation = nil
            windowController?.close()
            continuation.resume(returning: result)
        }
    }
}

private struct TranslationPreviewView: View {
    let original: String
    let replacement: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview Translation")
                .font(.title3)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("Original")
                    .font(.headline)
                ScrollView {
                    Text(original)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 120)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Replacement")
                    .font(.headline)
                ScrollView {
                    Text(replacement)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 120)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Replace", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
