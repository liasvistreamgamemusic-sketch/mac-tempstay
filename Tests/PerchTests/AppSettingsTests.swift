import XCTest
@testable import Perch

final class AppSettingsTests: XCTestCase {
    func testDefaultBindsEveryAction() {
        let settings = AppSettings.default
        for action in HotkeyAction.allCases {
            XCTAssertNotNil(settings.shortcuts[action], "missing default for \(action.rawValue)")
            XCTAssertTrue(settings.shortcut(for: action).isValid)
        }
    }

    func testShortcutFallsBackToDefaultWhenUnset() {
        var settings = AppSettings.default
        settings.shortcuts.removeValue(forKey: .clearShelf)
        XCTAssertEqual(settings.shortcut(for: .clearShelf), HotkeyAction.clearShelf.defaultShortcut)
    }

    func testCodableRoundTrip() throws {
        var original = AppSettings.default
        original.edge = .left
        original.autoHideDelay = 3.0
        original.skippedUpdateVersion = "v0.2.0"

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

final class KeyComboTests: XCTestCase {
    func testRequiresCommandOrControl() {
        let optionOnly = KeyCombo(keyCode: 9, modifierFlags: [.option, .shift])
        XCTAssertFalse(optionOnly.isValid)

        let withControl = KeyCombo(keyCode: 9, modifierFlags: [.control, .option])
        XCTAssertTrue(withControl.isValid)
    }

    func testStripsIrrelevantModifiers() {
        let combo = KeyCombo(keyCode: 9, modifierFlags: [.command, .capsLock, .function])
        XCTAssertEqual(combo.modifierFlags, [.command])
    }
}
