import XCTest
@testable import CaretTranslateApp

final class DebugLogStoreTests: XCTestCase {
    @MainActor
    func testAppendAddsEntry() {
        let store = DebugLogStore()

        store.append("Hello", timestamp: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.message, "Hello")
    }

    @MainActor
    func testObserverReceivesUpdates() {
        let store = DebugLogStore()
        var callCount = 0
        let token = store.addObserver { _ in
            callCount += 1
        }

        store.append("First", timestamp: Date(timeIntervalSince1970: 0))
        store.removeObserver(token)
        store.append("Second", timestamp: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(callCount, 1)
    }
}
