import OSLog

struct Signposter: Sendable {
    // MARK: Lifecycle

    init(category: String) {
        signposter = OSSignposter(
            subsystem: "com.finnvoorhees.CoreMLPipelines",
            category: category
        )
    }

    // MARK: Internal

    struct Interval {
        let name: StaticString
        let interval: OSSignpostIntervalState
        let signposter: OSSignposter

        func end(metadata: CustomStringConvertible? = nil) {
            if let metadata {
                signposter.endInterval(name, interval, "\(metadata.description)")
            } else {
                signposter.endInterval(name, interval)
            }
        }
    }

    func measure<T>(
        _ name: StaticString,
        metadata: CustomStringConvertible? = nil,
        _ body: () throws -> T
    ) rethrows -> T {
        let interval = begin(name, metadata: metadata)
        defer { interval.end(metadata: metadata) }
        return try body()
    }

    func measure<T>(
        _ name: StaticString,
        metadata: CustomStringConvertible? = nil,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let interval = begin(name, metadata: metadata)
        defer { interval.end(metadata: metadata) }
        return try await body()
    }

    func begin(_ name: StaticString, metadata: CustomStringConvertible? = nil) -> Interval {
        let interval = if let metadata {
            signposter.beginInterval(name, id: signposter.makeSignpostID(), "\(metadata.description)")
        } else {
            signposter.beginInterval(name, id: signposter.makeSignpostID())
        }
        return .init(name: name, interval: interval, signposter: signposter)
    }

    // MARK: Private

    private let signposter: OSSignposter
}
