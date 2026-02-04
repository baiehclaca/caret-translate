import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingResetAlert = false

    var body: some View {
        let sourceOptions = SupportedLanguages.all
        let targetOptions = SupportedLanguages.all.filter { $0.code != LanguageOption.auto.code }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.title3)
                    .bold()

                GroupBox("Languages") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Source Language", selection: $viewModel.sourceCode) {
                            ForEach(sourceOptions) { option in
                                Text(option.label).tag(option.code)
                            }
                        }
                        Picker("Target Language", selection: $viewModel.targetCode) {
                            ForEach(targetOptions) { option in
                                Text(option.label).tag(option.code)
                            }
                        }
                        Text("Uses Apple Translation on-device. Languages download automatically when needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Shortcut") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Mode", selection: $viewModel.shortcutMode) {
                            ForEach(ShortcutMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.shortcutMode == .hotkey {
                            HotkeyEditorView(key: $viewModel.hotkeyKey, modifiers: $viewModel.hotkeyModifiers)
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Translation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Preview Before Replacing", isOn: $viewModel.previewEnabled)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Startup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Launch at Login", isOn: $viewModel.launchAtLoginEnabled)
                        Text("Starts CaretTranslate automatically after you sign in. Approval may be required in System Settings > General > Login Items.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Reset") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: resetApp) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("Reset App & Restart")
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        Text("Clears all settings, caches, logs, and restarts the app. This cannot be undone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(20)
        }
        .onChange(of: viewModel.sourceCode) { _, newValue in
            viewModel.updateSource(code: newValue)
        }
        .onChange(of: viewModel.targetCode) { _, newValue in
            viewModel.updateTarget(code: newValue)
        }
        .alert("Reset App?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset & Restart", role: .destructive) {
                performReset()
            }
        } message: {
            Text("This will clear all settings, caches, and logs. The app will restart. This cannot be undone.")
        }
    }

    private func resetApp() {
        showingResetAlert = true
    }

    private func performReset() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.resetAppData()
        }
    }
}
