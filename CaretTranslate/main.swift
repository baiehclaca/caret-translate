import AppKit

let app = NSApplication.shared
ProcessInfo.processInfo.processName = "Caret Translate"
if let icon = NSImage(named: "AppIcon") {
    app.applicationIconImage = icon
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
