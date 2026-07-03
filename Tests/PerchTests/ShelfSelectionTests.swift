import XCTest
@testable import Perch

final class ShelfSelectionTests: XCTestCase {
    private var tempRoot: URL!
    private var storage: ItemStorage!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerchSelection-\(UUID().uuidString)", isDirectory: true)
        storage = ItemStorage(rootOverride: tempRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @MainActor
    func testSelectReplacesSelection() {
        let selection = ShelfSelection()
        let a = storage.makeTextItem("a")
        let b = storage.makeTextItem("b")
        selection.select(a.id)
        selection.select(b.id)
        XCTAssertFalse(selection.contains(a.id))
        XCTAssertTrue(selection.contains(b.id))
        XCTAssertEqual(selection.ids.count, 1)
    }

    @MainActor
    func testToggleAddsAndRemoves() {
        let selection = ShelfSelection()
        let a = storage.makeTextItem("a")
        let b = storage.makeTextItem("b")
        selection.select(a.id)
        selection.toggle(b.id)
        XCTAssertTrue(selection.contains(a.id))
        XCTAssertTrue(selection.contains(b.id))
        selection.toggle(a.id)
        XCTAssertFalse(selection.contains(a.id))
        XCTAssertTrue(selection.contains(b.id))
    }

    @MainActor
    func testSelectAllAndClear() {
        let selection = ShelfSelection()
        let items = [storage.makeTextItem("a"), storage.makeTextItem("b"), storage.makeTextItem("c")]
        selection.selectAll(items)
        XCTAssertEqual(selection.ids.count, 3)
        selection.clear()
        XCTAssertTrue(selection.isEmpty)
    }

    @MainActor
    func testPruneDropsMissingIds() {
        let selection = ShelfSelection()
        let a = storage.makeTextItem("a")
        let b = storage.makeTextItem("b")
        selection.selectAll([a, b])
        selection.prune(existing: [b])
        XCTAssertFalse(selection.contains(a.id))
        XCTAssertTrue(selection.contains(b.id))
    }
}
