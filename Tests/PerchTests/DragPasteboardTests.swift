import AppKit
import XCTest
@testable import Perch

final class DragPasteboardTests: XCTestCase {
    /// File/image items must vend a real file URL so destinations (including
    /// Electron/web targets) receive an actual file, not a promise.
    func testFileItemWritesFileURL() {
        let item = ShelfItem(kind: .file, title: "note.txt", storedFilename: "note.txt")
        let url = URL(fileURLWithPath: "/tmp/note.txt")

        let writer = DragPasteboard.writer(for: item, contentURL: url)
        let types = writer?.writableTypes(for: NSPasteboard.general) ?? []

        XCTAssertTrue(types.contains(.fileURL), "file items must advertise public.file-url")
    }

    func testImageItemWritesFileURL() {
        let item = ShelfItem(kind: .image, title: "shot.png", storedFilename: "shot.png")
        let url = URL(fileURLWithPath: "/tmp/shot.png")

        let types = DragPasteboard.writer(for: item, contentURL: url)?
            .writableTypes(for: NSPasteboard.general) ?? []

        XCTAssertTrue(types.contains(.fileURL))
    }

    /// A missing backing file leaves nothing to drag.
    func testFileItemWithoutContentURLYieldsNoWriter() {
        let item = ShelfItem(kind: .file, title: "gone.txt", storedFilename: "gone.txt")
        XCTAssertNil(DragPasteboard.writer(for: item, contentURL: nil))
    }

    /// Links vend a web URL (not a file URL).
    func testLinkItemWritesWebURL() {
        let item = ShelfItem(kind: .link, title: "Example", text: "https://example.com")
        let types = DragPasteboard.writer(for: item, contentURL: nil)?
            .writableTypes(for: NSPasteboard.general) ?? []

        XCTAssertTrue(types.contains(.URL))
        XCTAssertFalse(types.contains(.fileURL))
    }

    func testTextItemWritesString() {
        let item = ShelfItem(kind: .text, title: "snippet", text: "hello")
        let types = DragPasteboard.writer(for: item, contentURL: nil)?
            .writableTypes(for: NSPasteboard.general) ?? []

        XCTAssertTrue(types.contains(.string))
    }

    func testTextItemWithoutPayloadYieldsNoWriter() {
        let item = ShelfItem(kind: .text, title: "empty", text: nil)
        XCTAssertNil(DragPasteboard.writer(for: item, contentURL: nil))
    }
}
