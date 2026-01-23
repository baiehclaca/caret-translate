import AppKit
import ApplicationServices
import CaretTranslateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var doubleTabMonitor: DoubleTabMonitor?
    private var hotkeyMonitor: HotkeyMonitor?
    private var settingsObserver: Any?
    private var languageMenuItem: NSMenuItem?
    private let settingsWindowController = SettingsWindowController()
    private let debugWindowController = DebugWindowController()
    private let settings = SettingsStore()
    private let languageCatalogStore = LanguageCatalogStore()
    private lazy var coordinator = TranslationCoordinator(settings: settings)
    private let inputMonitoringPrompter = InputMonitoringPrompter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.log("App launched")
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
        configureStatusItem()
        configureShortcutMonitor()
        observeSettingsChanges()
        coordinator.warmUp()
    }

    func applicationWillTerminate(_ notification: Notification) {
        doubleTabMonitor?.stop()
        hotkeyMonitor?.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
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

        let debugItem = NSMenuItem(
            title: "Debug Log...",
            action: #selector(handleOpenDebugLog),
            keyEquivalent: "d"
        )
        debugItem.target = self
        menu.addItem(debugItem)
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

    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureShortcutMonitor()
                self?.rebuildLanguageMenu()
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

    @objc private func handleOpenDebugLog() {
        debugWindowController.showWindow(nil)
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
        var items = languageCatalogStore.loadSource().map(LanguageMenuItem.init)
        if items.isEmpty {
            items = [LanguageMenuItem(code: settings.sourceLanguage.code, name: settings.sourceLanguage.code.uppercased())]
        }
        if !items.contains(where: { $0.code == Language.auto.code }) {
            items.insert(LanguageMenuItem(code: Language.auto.code, name: "Auto Detect"), at: 0)
        }
        return items
    }

    private func targetMenuItems() -> [LanguageMenuItem] {
        var items = languageCatalogStore.loadTarget().map(LanguageMenuItem.init)
        if items.isEmpty {
            items = [LanguageMenuItem(code: settings.targetLanguage.code, name: settings.targetLanguage.code.uppercased())]
        }
        return items
    }

    private func loadStatusIcon() -> NSImage? {
        if let symbol = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Caret Translate") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            return symbol.withSymbolConfiguration(config) ?? symbol
        }
        if let image = NSImage(named: "StatusIcon") {
            return image
        }
        if let url = Bundle.module.url(forResource: "status-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
