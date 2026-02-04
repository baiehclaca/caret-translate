import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @StateObject private var historyStore = TranslationHistoryStore()

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            ModelManagerView()
                .tabItem { Label("Models", systemImage: "arrow.down.circle") }

            HistorySettingsView(viewModel: viewModel, historyStore: historyStore)
                .tabItem { Label("History", systemImage: "clock") }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}
