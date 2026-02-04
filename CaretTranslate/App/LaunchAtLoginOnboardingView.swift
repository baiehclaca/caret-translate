import SwiftUI

/// Presents a first-run welcome screen with essential settings.
struct LaunchAtLoginOnboardingView: View {
    @State private var sourceLanguage: String = LanguageOption.auto.code
    @State private var targetLanguage: String = "en"
    @State private var shortcutMode: ShortcutMode = .doubleTap
    @State private var launchAtLoginEnabled: Bool
    private let onComplete: (Bool, String, String, ShortcutMode) -> Void
    private let openSettings: () -> Void

    /// Creates the onboarding view with initial settings and completion handlers.
    init(
        initiallyEnabled: Bool,
        onComplete: @escaping (Bool, String, String, ShortcutMode) -> Void,
        openSettings: @escaping () -> Void
    ) {
        self._launchAtLoginEnabled = State(initialValue: initiallyEnabled)
        self.onComplete = onComplete
        self.openSettings = openSettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to CaretTranslate")
                        .font(.title)
                        .bold()

                    Text("Set up your translation preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Languages
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Languages", systemImage: "globe")
                            .font(.headline)

                        Picker("Source Language", selection: $sourceLanguage) {
                            ForEach(SupportedLanguages.all) { option in
                                Text(option.label).tag(option.code)
                            }
                        }

                        Picker("Target Language", selection: $targetLanguage) {
                            ForEach(SupportedLanguages.all.filter { $0.code != LanguageOption.auto.code }) { option in
                                Text(option.label).tag(option.code)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Shortcut
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Translation Shortcut", systemImage: "keyboard")
                            .font(.headline)

                        Picker("Shortcut Mode", selection: $shortcutMode) {
                            ForEach(ShortcutMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(shortcutMode == .doubleTap
                            ? "Press Tab twice quickly to translate"
                            : "Set your custom hotkey in Settings after setup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Launch at Login
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Startup", systemImage: "power")
                            .font(.headline)

                        Toggle("Launch at Login", isOn: $launchAtLoginEnabled)

                        Text("CaretTranslate will start automatically when you sign in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // First Start Notice
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Note: The app may occasionally experience minor issues on first start. If this happens, simply restart the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                // Credits
                HStack {
                    Spacer()
                    Text("Programmed by Teodor and Claude with LOVE! ❤️")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }

                // Buttons
                HStack {
                    Button("Not Now", action: handleSkip)
                    Spacer()
                    Button("Get Started", action: handleContinue)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }

                Button("Open Login Items Settings", action: openSettings)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(32)
        }
        .frame(minWidth: 500, maxWidth: 600, minHeight: 550, maxHeight: 700)
    }

    /// Completes onboarding and applies the selected settings.
    private func handleContinue() {
        onComplete(launchAtLoginEnabled, sourceLanguage, targetLanguage, shortcutMode)
    }

    /// Completes onboarding with default settings.
    private func handleSkip() {
        onComplete(false, sourceLanguage, targetLanguage, shortcutMode)
    }
}
