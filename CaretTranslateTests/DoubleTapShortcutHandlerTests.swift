import XCTest
@testable import CaretTranslate

final class DoubleTapShortcutHandlerTests: XCTestCase {
    func testTriggersOnDoubleTabWithoutModifiers() {
        let handler = DoubleTapShortcutHandler(targetKey: "\t", threshold: 0.3)

        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.0)), .pending)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.2)), .triggered)
    }

    func testIgnoresNonTabKey() {
        let handler = DoubleTapShortcutHandler(targetKey: "\t", threshold: 0.3)

        XCTAssertEqual(handler.register(keyPress: makeKeyPress("a", timestamp: 1.0)), .ignored)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.1)), .pending)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.3)), .triggered)
    }

    func testIgnoresRepeats() {
        let handler = DoubleTapShortcutHandler(targetKey: "\t", threshold: 0.3)

        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", isRepeat: true, timestamp: 1.0)), .ignored)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.1)), .pending)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.3)), .triggered)
    }

    func testIgnoresModifiers() {
        let handler = DoubleTapShortcutHandler(targetKey: "\t", threshold: 0.3)

        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", modifiers: [.command], timestamp: 1.0)), .ignored)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.1)), .pending)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.3)), .triggered)
    }

    func testResetsAfterNonTabKey() {
        let handler = DoubleTapShortcutHandler(targetKey: "\t", threshold: 0.3)

        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.0)), .pending)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("x", timestamp: 1.1)), .ignored)
        XCTAssertEqual(handler.register(keyPress: makeKeyPress("\t", timestamp: 1.2)), .pending)
    }
}

private func makeKeyPress(
    _ key: String,
    modifiers: KeyModifiers = [],
    isRepeat: Bool = false,
    timestamp: TimeInterval
) -> KeyPress {
    KeyPress(key: key, modifiers: modifiers, isRepeat: isRepeat, timestamp: timestamp)
}
