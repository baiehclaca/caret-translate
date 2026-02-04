import SwiftUI

/// Presents a first-run prompt to enable launch at login.
struct LaunchAtLoginOnboardingView: View {
    @State private var launchAtLoginEnabled: Bool
    private let onComplete: (Bool) -> Void
    private let openSettings: () -> Void

    /// Creates the onboarding view with initial toggle state and completion handlers.
    init(
        initiallyEnabled: Bool,
        onComplete: @escaping (Bool) -> Void,
        openSettings: @escaping () -> Void
    ) {
        self._launchAtLoginEnabled = State(initialValue: initiallyEnabled)
        self.onComplete = onComplete
        self.openSettings = openSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to CaretTranslate")
                .font(.title2)
                .bold()

            Text("Enable launch at login so CaretTranslate is ready whenever you sign in. You can change this later in Settings.")
                .foregroundColor(.secondary)

            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)

            HStack {
                Button("Not Now", action: handleSkip)
                Spacer()
                Button("Continue", action: handleContinue)
                    .keyboardShortcut(.defaultAction)
            }

            Button("Open Login Items Settings", action: openSettings)
                .font(.footnote)
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 240)
    }

    /// Completes onboarding and applies the selected launch-at-login state.
    private func handleContinue() {
        onComplete(launchAtLoginEnabled)
    }

    /// Completes onboarding without enabling launch at login.
    private func handleSkip() {
        onComplete(false)
    }
}
