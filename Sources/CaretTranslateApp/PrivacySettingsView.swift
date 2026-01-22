import AppKit
import SwiftUI

struct PrivacySettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var allowSelection: Set<String> = []
    @State private var denySelection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Rules")
                .font(.title3)
                .bold()

            Text("If the allowlist has entries, only those apps can be translated. Secure fields are always blocked.")
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 16) {
                listSection(
                    title: "Allowlist",
                    items: viewModel.allowlistBundleIds,
                    selection: $allowSelection,
                    addAction: { addCurrentApp(to: .allowlist) },
                    removeAction: { viewModel.removeAllowlist(bundleIds: allowSelection) }
                )

                listSection(
                    title: "Denylist",
                    items: viewModel.denylistBundleIds,
                    selection: $denySelection,
                    addAction: { addCurrentApp(to: .denylist) },
                    removeAction: { viewModel.removeDenylist(bundleIds: denySelection) }
                )
            }
        }
        .padding(20)
    }

    private func listSection(
        title: String,
        items: [String],
        selection: Binding<Set<String>>,
        addAction: @escaping () -> Void,
        removeAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            List(items, id: \.self, selection: selection) { bundleId in
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppDisplayNameResolver.displayName(for: bundleId))
                        .font(.subheadline)
                    Text(bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 220, minHeight: 200)

            HStack {
                Button("Add Current App", action: addAction)
                Button("Remove Selected", action: removeAction)
                    .disabled(selection.wrappedValue.isEmpty)
            }
        }
    }

    private enum ListType {
        case allowlist
        case denylist
    }

    private func addCurrentApp(to list: ListType) {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return
        }
        switch list {
        case .allowlist:
            viewModel.addAllowlist(bundleId: bundleId)
        case .denylist:
            viewModel.addDenylist(bundleId: bundleId)
        }
    }
}
