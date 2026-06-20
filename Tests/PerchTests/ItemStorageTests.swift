import XCTest
@testable import Perch

final class ItemStorageTests: XCTestCase {
    private var tempRoot: URL!
    private var storage: ItemStorage!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerchTests-\(UUID().uuidString)", isDirectory: true)
        storage = ItemStorage(rootOverride: tempRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testStoreFileCopiesContentAndSurvivesSourceDeletion() throws {
        let source = tempRoot.appendingPathComponent("note.txt")
        try "hello".data(using: .utf8)!.write(to: source)

        let item = try storage.storeFile(at: source)
        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.title, "note.txt")

        // Deleting the original must not break the stored copy.
        try FileManager.default.removeItem(at: source)
        let stored = storage.contentURL(for: item)
        XCTAssertNotNil(stored)
        XCTAssertEqual(try String(contentsOf: stored!, encoding: .utf8), "hello")
    }

    func testImageFileDetectedAsImageKind() throws {
        let source = tempRoot.appendingPathComponent("pixel.png")
        try Self.onePixelPNG().write(to: source)

        let item = try storage.storeFile(at: source)
        XCTAssertEqual(item.kind, .image)
    }

    func testInlineItemsTouchNoDisk() {
        let text = storage.makeTextItem("some snippet")
        XCTAssertEqual(text.kind, .text)
        XCTAssertNil(storage.contentURL(for: text))

        let link = storage.makeLinkItem(URL(string: "https://example.com")!)
        XCTAssertEqual(link.kind, .link)
        XCTAssertEqual(link.text, "https://example.com")
    }

    func testRemoveDeletesStoredContent() throws {
        let source = tempRoot.appendingPathComponent("doc.txt")
        try "x".data(using: .utf8)!.write(to: source)
        let item = try storage.storeFile(at: source)
        XCTAssertNotNil(storage.contentURL(for: item))

        storage.remove(item)
        XCTAssertNil(storage.contentURL(for: item))
    }

    func testMetadataRoundTrip() throws {
        let items = [storage.makeTextItem("a"), storage.makeLinkItem(URL(string: "https://b.com")!)]
        storage.saveMetadata(items)
        let loaded = storage.loadMetadata()
        XCTAssertEqual(loaded.map(\.id), items.map(\.id))
    }

    func testPruneOrphansRemovesUnreferencedDirectories() throws {
        let source = tempRoot.appendingPathComponent("keep.txt")
        try "k".data(using: .utf8)!.write(to: source)
        let kept = try storage.storeFile(at: source)

        let source2 = tempRoot.appendingPathComponent("drop.txt")
        try "d".data(using: .utf8)!.write(to: source2)
        let dropped = try storage.storeFile(at: source2)

        storage.pruneOrphans(keeping: [kept])
        XCTAssertNotNil(storage.contentURL(for: kept))
        XCTAssertNil(storage.contentURL(for: dropped))
    }

    /// Minimal valid 1×1 PNG.
    private static func onePixelPNG() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64)!
    }
}
