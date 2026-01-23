import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @StateObject private var historyStore = TranslationHistoryStore()
    @StateObject private var dictionaryStore = CustomDictionaryStore()
    private let cacheStore = TranslationCacheStore.shared

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel, cacheStore: cacheStore)
                .tabItem { Text("General") }

            PrivacySettingsView(viewModel: viewModel)
                .tabItem { Text("Privacy") }

            HistorySettingsView(viewModel: viewModel, historyStore: historyStore)
                .tabItem { Text("History") }

            StatusHealthView()
                .tabItem { Text("Status") }

            ExperimentalSettingsView(viewModel: viewModel, dictionaryStore: dictionaryStore)
                .tabItem { Text("Experimental") }
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
