import SwiftUI
import CaretTranslateCore

struct HotkeyEditorView: View {
    @Binding var key: String
    @Binding var modifiers: HotkeyModifier

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Key")
                    .frame(width: 40, alignment: .leading)
                TextField("Key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack(spacing: 12) {
                Toggle("Cmd", isOn: binding(for: .command))
                Toggle("Opt", isOn: binding(for: .option))
                Toggle("Ctrl", isOn: binding(for: .control))
                Toggle("Shift", isOn: binding(for: .shift))
            }
        }
    }

    private func binding(for modifier: HotkeyModifier) -> Binding<Bool> {
        Binding(
            get: { modifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    modifiers.insert(modifier)
                } else {
                    modifiers.remove(modifier)
                }
            }
        )
    }
}
