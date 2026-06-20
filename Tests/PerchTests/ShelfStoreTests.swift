import XCTest
@testable import Perch

@MainActor
final class ShelfStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var storage: ItemStorage!
    private var settings: SettingsStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerchStore-\(UUID().uuidString)", isDirectory: true)
        storage = ItemStorage(rootOverride: tempRoot)
        let defaults = UserDefaults(suiteName: "PerchTests-\(UUID().uuidString)")!
        settings = SettingsStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testAddInsertsNewestFirst() {
        let store = ShelfStore(storage: storage, settingsStore: settings)
        let first = storage.makeTextItem("first")
        let second = storage.makeTextItem("second")
        store.add([first])
        store.add([second])
        XCTAssertEqual(store.items.first?.id, second.id)
        XCTAssertEqual(store.count, 2)
    }

    func testAddDeduplicatesById() {
        let store = ShelfStore(storage: storage, settingsStore: settings)
        let item = storage.makeTextItem("dup")
        store.add([item])
        store.add([item])
        XCTAssertEqual(store.count, 1)
    }

    func testRemoveAndClear() {
        let store = ShelfStore(storage: storage, settingsStore: settings)
        let a = storage.makeTextItem("a")
        let b = storage.makeTextItem("b")
        store.add([a, b])
        store.remove(a)
        XCTAssertEqual(store.count, 1)
        store.clear()
        XCTAssertTrue(store.isEmpty)
    }

    func testPersistenceAcrossStoreInstances() throws {
        let store = ShelfStore(storage: storage, settingsStore: settings)
        store.add([storage.makeTextItem("persisted")])

        // A fresh store over the same storage should reload the item.
        let reopened = ShelfStore(storage: ItemStorage(rootOverride: tempRoot), settingsStore: settings)
        XCTAssertEqual(reopened.count, 1)
        XCTAssertEqual(reopened.items.first?.title, "persisted")
    }

    func testDoesNotPersistWhenDisabled() {
        settings.update { $0.persistItemsAcrossLaunches = false }
        let store = ShelfStore(storage: storage, settingsStore: settings)
        store.add([storage.makeTextItem("ephemeral")])

        let reopened = ShelfStore(storage: ItemStorage(rootOverride: tempRoot), settingsStore: settings)
        XCTAssertTrue(reopened.isEmpty)
    }
}

@MainActor
final class ShelfEdgeTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 240, height: 420)

    func testLeftEdgeDocksAtMinX() {
        let frame = ShelfEdge.left.shelfFrame(size: size, on: screen, gap: 8)
        XCTAssertEqual(frame.minX, 8)
        XCTAssertEqual(frame.midY, screen.midY)
    }

    func testRightEdgeDocksAtMaxX() {
        let frame = ShelfEdge.right.shelfFrame(size: size, on: screen, gap: 8)
        XCTAssertEqual(frame.maxX, screen.maxX - 8)
    }

    func testHiddenFrameSitsOffScreen() {
        let left = ShelfEdge.left.hiddenFrame(size: size, on: screen)
        XCTAssertLessThan(left.maxX, screen.minX + 1)
        let right = ShelfEdge.right.hiddenFrame(size: size, on: screen)
        XCTAssertGreaterThanOrEqual(right.minX, screen.maxX)
    }
}
