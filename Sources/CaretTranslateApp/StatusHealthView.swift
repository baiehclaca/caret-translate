import ApplicationServices
import IOKit.hidsystem
import SwiftUI
import CaretTranslateCore

struct StatusHealthView: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var inputMonitoringAccess: IOHIDAccessType = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    @State private var apiKeyConfigured = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status Health")
                .font(.title3)
                .bold()

            statusRow(title: "Accessibility", isGood: accessibilityGranted)
            statusRow(title: "Input Monitoring", isGood: inputMonitoringAccess == kIOHIDAccessTypeGranted)
            statusRow(title: "DeepL API Key", isGood: apiKeyConfigured)

            Button("Refresh") {
                refresh()
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(20)
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        apiKeyConfigured = (ApiKeyStore().apiKey?.isEmpty == false)
    }

    private func statusRow(title: String, isGood: Bool) -> some View {
        HStack {
            Circle()
                .fill(isGood ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text(isGood ? "OK" : "Needs Attention")
                .foregroundColor(.secondary)
        }
    }
}
