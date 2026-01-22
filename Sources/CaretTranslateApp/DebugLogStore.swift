import Foundation

struct DebugLogEntry: Equatable {
    let timestamp: Date
    let message: String
}

@MainActor
final class DebugLogStore {
    static let shared = DebugLogStore()

    private(set) var entries: [DebugLogEntry] = []
    private var observers: [UUID: (DebugLogStore) -> Void] = [:]

    func append(_ message: String, timestamp: Date = Date()) {
        entries.append(DebugLogEntry(timestamp: timestamp, message: message))
        notifyObservers()
    }

    func clear() {
        entries.removeAll()
        notifyObservers()
    }

    func addObserver(_ observer: @escaping (DebugLogStore) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func notifyObservers() {
        for observer in observers.values {
            observer(self)
        }
    }
}
