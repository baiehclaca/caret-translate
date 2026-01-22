import Foundation

enum DebugLogger {
    static func log(_ message: String) {
        Task { @MainActor in
            DebugLogStore.shared.append(message)
        }
    }
}
