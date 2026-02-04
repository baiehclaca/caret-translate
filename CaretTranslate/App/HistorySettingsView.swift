import SwiftUI

struct HistorySettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var historyStore: TranslationHistoryStore
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Translation History")
                .font(.title3)
                .bold()

            Toggle("Enable History", isOn: $viewModel.historyEnabled)

            HStack(spacing: 16) {
                Stepper(value: $viewModel.historyRetentionCount, in: 10...1000, step: 10) {
                    Text("Keep last \(viewModel.historyRetentionCount) items")
                }
                Stepper(value: $viewModel.historyRetentionDays, in: 1...365, step: 1) {
                    Text("Keep for \(viewModel.historyRetentionDays) days")
                }
            }

            HStack {
                Spacer()
                Button("Clear History") {
                    showClearConfirmation = true
                }
            }

            List(historyStore.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.translatedText)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text(entry.sourceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text("\(entry.sourceLanguage.uppercased()) → \(entry.targetLanguage.uppercased())")
                        Text(entry.timestamp, style: .time)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .alert("Clear Translation History?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                historyStore.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your saved translations.")
        }
        .onChange(of: viewModel.historyRetentionCount) { _, _ in
            historyStore.prune(referenceDate: Date())
        }
        .onChange(of: viewModel.historyRetentionDays) { _, _ in
            historyStore.prune(referenceDate: Date())
        }
        .onChange(of: viewModel.historyEnabled) { _, enabled in
            if !enabled {
                historyStore.clear()
            }
        }
    }
}
