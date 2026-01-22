import SwiftUI

struct ExperimentalSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var dictionaryStore: CustomDictionaryStore
    @State private var sourceWord = ""
    @State private var targetWord = ""
    @State private var sourceLang = ""
    @State private var targetLang = ""
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Experimental Tools")
                .font(.title3)
                .bold()

            GroupBox("Custom Dictionary") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Source Lang", text: $sourceLang)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        TextField("Target Lang", text: $targetLang)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Text("\(sourceLang.uppercased()) → \(targetLang.uppercased())")
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        TextField("Source word", text: $sourceWord)
                            .textFieldStyle(.roundedBorder)
                        TextField("Target word", text: $targetWord)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            dictionaryStore.addEntry(
                                source: sourceWord,
                                target: targetWord,
                                sourceLanguage: sourceLang,
                                targetLanguage: targetLang
                            )
                            sourceWord = ""
                            targetWord = ""
                        }
                    }

                    List(dictionaryStore.entries, selection: $selection) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.source) → \(entry.target)")
                                .font(.subheadline)
                            Text("\(entry.sourceLanguage.uppercased()) → \(entry.targetLanguage.uppercased())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(minHeight: 200)

                    HStack {
                        Button("Remove Selected") {
                            dictionaryStore.remove(ids: selection)
                        }
                        .disabled(selection.isEmpty)
                        Spacer()
                        Button("Clear All") {
                            dictionaryStore.clear()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .onAppear {
            sourceLang = viewModel.sourceCode
            targetLang = viewModel.targetCode
        }
        .onChange(of: viewModel.sourceCode) { _, newValue in
            sourceLang = newValue
        }
        .onChange(of: viewModel.targetCode) { _, newValue in
            targetLang = newValue
        }
    }
}
