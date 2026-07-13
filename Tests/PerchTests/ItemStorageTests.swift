import ImageIO
import UniformTypeIdentifiers
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

    func testStoreImageDataKeepsPNGBytesVerbatim() throws {
        // A pasteboard PNG must survive ingestion byte-for-byte. Re-encoding
        // rewrites color metadata (an sRGB chunk becomes an inverted gAMA tag),
        // which brightens the image in gAMA-honoring viewers like Teams.
        let png = Self.sRGBChunkPNG()

        let item = try storage.storeImageData(png, suggestedName: "shot")
        let stored = try XCTUnwrap(storage.contentURL(for: item))
        XCTAssertEqual(try Data(contentsOf: stored), png)
    }

    func testStoreImageDataTranscodesTIFFKeepingColorProfile() throws {
        let tiff = try Self.onePixelData(as: .tiff, colorSpaceName: CGColorSpace.displayP3)

        let item = try storage.storeImageData(tiff, suggestedName: "shot")
        let stored = try XCTUnwrap(storage.contentURL(for: item))
        XCTAssertEqual(stored.pathExtension, "png")

        let data = try Data(contentsOf: stored)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyProfileName] as? String, "Display P3")
    }

    func testStoreImageDataRejectsUndecodableData() {
        XCTAssertThrowsError(
            try storage.storeImageData(Data("not an image".utf8), suggestedName: "junk"))
    }

    /// Minimal valid 1×1 PNG.
    private static func onePixelPNG() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64)!
    }

    /// A 1×1 gray PNG whose color is declared via an `sRGB` chunk (no ICC
    /// profile) — the format screenshot tools put on the pasteboard.
    private static func sRGBChunkPNG() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAXNSR0IArs4c6QAAAAxJREFUeJxjaGhoAAADBAGBS9PSEAAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64)!
    }

    /// A 1×1 image encoded as `type`, tagged with the given color space.
    private static func onePixelData(as type: UTType, colorSpaceName: CFString) throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(try XCTUnwrap(CGColor(colorSpace: colorSpace, components: [1, 0, 0, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = try XCTUnwrap(context.makeImage())

        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
