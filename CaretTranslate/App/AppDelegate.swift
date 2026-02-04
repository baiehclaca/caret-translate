import AppKit
import ApplicationServices
import SwiftUI

@available(macOS 15.0, *)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var doubleTabMonitor: DoubleTabMonitor?
    private var hotkeyMonitor: HotkeyMonitor?
    private var settingsObserver: Any?
    private var languageMenuItem: NSMenuItem?
    private var translationWorkerWindow: NSWindow?
    private let settingsWindowController = SettingsWindowController()
    private let onboardingWindowController = LaunchAtLoginOnboardingWindowController()
    private let settings = SettingsStore()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private lazy var coordinator = TranslationCoordinator(settings: settings)
    private let inputMonitoringPrompter = InputMonitoringPrompter()
    private var lastLaunchAtLoginEnabled: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.log("App launched")
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
        configureTranslationWorker()
        coordinator.normalizeLanguageSelectionIfNeeded()
        coordinator.warmUpTranslationOnLaunch()
        configureStatusItem()
        configureShortcutMonitor()
        if !presentOnboardingIfNeeded() {
            syncLaunchAtLogin(force: true)
        }
        observeSettingsChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        doubleTabMonitor?.stop()
        hotkeyMonitor?.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        coordinator.shutdown()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = loadStatusIcon() {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
            item.button?.title = ""
        } else {
            item.button?.title = "Translate"
        }
        let menu = NSMenu()
        menu.delegate = self

        let translateItem = NSMenuItem(
            title: "Translate Now",
            action: #selector(handleTranslate),
            keyEquivalent: ""
        )
        translateItem.target = self
        menu.addItem(translateItem)
        menu.addItem(NSMenuItem.separator())

        let languageItem = NSMenuItem(title: "Languages", action: nil, keyEquivalent: "")
        languageItem.submenu = NSMenu()
        languageMenuItem = languageItem
        menu.addItem(languageItem)
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func configureShortcutMonitor() {
        doubleTabMonitor?.stop()
        hotkeyMonitor?.stop()

        switch settings.shortcutMode {
        case .doubleTap:
            doubleTabMonitor = DoubleTabMonitor(
                trigger: { [weak self] in
                    Task { @MainActor in
                        self?.handleTranslate()
                    }
                },
                prefetch: { [weak self] in
                    Task { @MainActor in
                        self?.handlePrefetch()
                    }
                },
                cancelPrefetch: { [weak self] in
                    Task { @MainActor in
                        self?.handleCancelPrefetch()
                    }
                }
            )
            if doubleTabMonitor?.start() != true {
                DebugLogger.log("Input monitoring unavailable for shortcut")
                showInputMonitoringAlert()
            } else {
                DebugLogger.log("Double-tab shortcut enabled")
            }
        case .hotkey:
            let binding = settings.hotkeyBinding
            let flags = binding.modifiers.toModifierFlags()
            if binding.key.isEmpty {
                DebugLogger.log("Hotkey not configured")
                return
            }
            hotkeyMonitor = HotkeyMonitor(key: binding.key, modifiers: flags) { [weak self] in
                Task { @MainActor in
                    self?.handleTranslate()
                }
            }
            hotkeyMonitor?.start()
            DebugLogger.log("Custom hotkey enabled")
        }
    }

    /// Keeps a hidden SwiftUI view alive to drive Translation framework sessions.
    private func configureTranslationWorker() {
        let hostingController = NSHostingController(rootView: TranslationWorkerView())
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.setFrame(NSRect(x: -10000, y: -10000, width: 1, height: 1), display: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.alphaValue = 0.0
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        window.orderFront(nil)
        translationWorkerWindow = window
    }

    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureShortcutMonitor()
                self?.rebuildLanguageMenu()
                self?.syncLaunchAtLogin(force: false)
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildLanguageMenu()
    }

    private func requestAccessibilityIfNeeded() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DebugLogger.log("Accessibility permission: \(trusted ? "granted" : "prompted")")
    }

    private func requestInputMonitoringIfNeeded() {
        let granted = inputMonitoringPrompter.ensureAccess()
        DebugLogger.log("Input monitoring permission: \(granted ? "granted" : "prompted")")
        if !granted {
            showInputMonitoringAlert()
        }
    }

    private func showInputMonitoringAlert() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring Required"
        alert.informativeText = "Enable Input Monitoring for CaretTranslate in System Settings > Privacy & Security so the Tab shortcut can be detected."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleTranslate() {
        coordinator.translateNearestWord()
    }

    @objc private func handlePrefetch() {
        coordinator.prefetchTranslation()
    }

    @objc private func handleCancelPrefetch() {
        coordinator.cancelPrefetch()
    }

    @objc private func handleOpenSettings() {
        settingsWindowController.show()
    }

    @objc private func handleSourceLanguageSelect(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else {
            return
        }
        settings.sourceLanguage = Language(code: code)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    @objc private func handleTargetLanguageSelect(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else {
            return
        }
        settings.targetLanguage = Language(code: code)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    @objc private func handleSwapLanguages() {
        let source = settings.sourceLanguage
        settings.sourceLanguage = settings.targetLanguage
        settings.targetLanguage = source
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        coordinator.normalizeLanguageSelectionIfNeeded()
    }

    private func rebuildLanguageMenu() {
        guard let submenu = languageMenuItem?.submenu else {
            return
        }
        submenu.removeAllItems()

        let sourceHeader = NSMenuItem(title: "Source Language", action: nil, keyEquivalent: "")
        sourceHeader.isEnabled = false
        submenu.addItem(sourceHeader)

        for item in sourceMenuItems() {
            let menuItem = NSMenuItem(title: item.label, action: #selector(handleSourceLanguageSelect), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.code
            menuItem.state = item.code == settings.sourceLanguage.code ? .on : .off
            submenu.addItem(menuItem)
        }

        submenu.addItem(NSMenuItem.separator())

        let targetHeader = NSMenuItem(title: "Target Language", action: nil, keyEquivalent: "")
        targetHeader.isEnabled = false
        submenu.addItem(targetHeader)

        for item in targetMenuItems() {
            let menuItem = NSMenuItem(title: item.label, action: #selector(handleTargetLanguageSelect), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.code
            menuItem.state = item.code == settings.targetLanguage.code ? .on : .off
            submenu.addItem(menuItem)
        }

        submenu.addItem(NSMenuItem.separator())
        let swapItem = NSMenuItem(title: "Swap Source/Target", action: #selector(handleSwapLanguages), keyEquivalent: "")
        swapItem.target = self
        submenu.addItem(swapItem)
    }

    private func sourceMenuItems() -> [LanguageMenuItem] {
        SupportedLanguages.all.map(LanguageMenuItem.init)
    }

    private func targetMenuItems() -> [LanguageMenuItem] {
        SupportedLanguages.all
            .filter { $0.code != LanguageOption.auto.code }
            .map(LanguageMenuItem.init)
    }

    private func loadStatusIcon() -> NSImage? {
        if let symbol = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Caret Translate") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            return symbol.withSymbolConfiguration(config) ?? symbol
        }
        if let image = NSImage(named: "StatusIcon") {
            return image
        }
        if let url = Bundle.main.url(forResource: "status-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    /// Applies the launch-at-login setting when it changes.
    private func syncLaunchAtLogin(force: Bool) {
        guard settings.onboardingCompleted else {
            return
        }
        let enabled = settings.launchAtLoginEnabled
        if !force, lastLaunchAtLoginEnabled == enabled {
            return
        }
        lastLaunchAtLoginEnabled = enabled
        switch launchAtLoginManager.sync(enabled: enabled) {
        case .success:
            break
        case .failure(let error):
            DebugLogger.log("ERROR: Launch at login sync failed: \(error.description)")
            showLaunchAtLoginAlert(for: error)
        }
    }

    /// Presents guidance when launch-at-login needs approval or fails.
    private func showLaunchAtLoginAlert(for error: LaunchAtLoginError) {
        let alert = NSAlert()
        alert.messageText = "Launch at Login Update Failed"
        alert.informativeText = error.description + " You can review this in System Settings > General > Login Items."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Presents the onboarding window if the user has not completed it yet.
    @discardableResult
    private func presentOnboardingIfNeeded() -> Bool {
        guard !settings.onboardingCompleted else {
            return false
        }
        onboardingWindowController.show(initiallyEnabled: true) { [weak self] enabled in
            Task { @MainActor in
                self?.completeOnboarding(launchAtLoginEnabled: enabled)
            }
        }
        return true
    }

    /// Finalizes onboarding, persists the chosen setting, and syncs launch at login.
    private func completeOnboarding(launchAtLoginEnabled: Bool) {
        settings.launchAtLoginEnabled = launchAtLoginEnabled
        settings.onboardingCompleted = true
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        onboardingWindowController.close()
        syncLaunchAtLogin(force: true)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    @objc func resetAppData() {
        // Clear all UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
        }

        // Clear application support directory (logs, caches, etc.)
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appendingPathComponent("CaretTranslate")
            try? FileManager.default.removeItem(at: appDir)
        }

        // Clear caches directory
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let appCache = caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "CaretTranslate")
            try? FileManager.default.removeItem(at: appCache)
        }

        // Clear temporary directory
        let tmp = FileManager.default.temporaryDirectory
        if let contents = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for item in contents {
                try? FileManager.default.removeItem(at: item)
            }
        }

        // Restart the app
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [Bundle.main.bundlePath]
        task.launch()

        NSApp.terminate(nil)
    }
}
