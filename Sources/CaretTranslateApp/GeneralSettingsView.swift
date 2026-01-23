import SwiftUI
import CaretTranslateCore

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let cacheStore: TranslationCacheStore

    var body: some View {
        let sourceOptions = viewModel.sourceLanguages.isEmpty ? fallbackSourceLanguageOptions : viewModel.sourceLanguages
        let targetOptions = viewModel.targetLanguages.isEmpty ? fallbackTargetLanguageOptions : viewModel.targetLanguages

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.title3)
                    .bold()

                GroupBox("DeepL") {
                    VStack(alignment: .leading, spacing: 12) {
                        SecureField("API Key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                viewModel.saveApiKey()
                                viewModel.refreshLanguages()
                            }

                        HStack(spacing: 12) {
                            Button("Save & Load Languages") {
                                viewModel.saveApiKey()
                                viewModel.refreshLanguages()
                            }
                            .keyboardShortcut(.defaultAction)

                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Preview Before Replacing", isOn: $viewModel.previewEnabled)

                        Picker("Formality", selection: $viewModel.translationFormality) {
                            ForEach(TranslationFormality.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        Picker("Performance", selection: $viewModel.performanceMode) {
                            ForEach(PerformanceMode.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        HStack {
                            Button("Clear Translation Cache") {
                                Task {
                                    await cacheStore.clear()
                                }
                            }
                            Spacer()
                        }
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
        .onAppear {
            let trimmedKey = viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                viewModel.refreshLanguages()
            }
        }
    }
}

private let fallbackSourceLanguageOptions: [LanguageOption] = [
    .auto,
    LanguageOption(code: "en", name: "English"),
    LanguageOption(code: "sk", name: "Slovak")
]

private let fallbackTargetLanguageOptions: [LanguageOption] = [
    LanguageOption(code: "en", name: "English"),
    LanguageOption(code: "sk", name: "Slovak")
]
