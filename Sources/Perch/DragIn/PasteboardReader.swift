import AppKit
import UniformTypeIdentifiers

/// Turns the contents of an `NSPasteboard` — whether the dragging pasteboard or
/// the general clipboard — into `ShelfItem`s, copying file/image payloads into
/// the store. The single ingestion path for everything that lands on the shelf.
struct PasteboardReader {
    private let storage: ItemStorage

    init(storage: ItemStorage) {
        self.storage = storage
    }

    /// The pasteboard types the shelf advertises as droppable.
    static let acceptedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL, .URL, .tiff, .png, .string
    ]

    /// Reads every item from `pasteboard`, returning the shelf items to add.
    /// File URLs win over inline representations so dragging a file from Finder
    /// stores the file, not its path-as-text.
    func items(from pasteboard: NSPasteboard) -> [ShelfItem] {
        if let fileItems = fileItems(from: pasteboard), !fileItems.isEmpty {
            return fileItems
        }
        if let image = imageItem(from: pasteboard) {
            return [image]
        }
        if let link = linkItem(from: pasteboard) {
            return [link]
        }
        if let text = textItem(from: pasteboard) {
            return [text]
        }
        return []
    }

    // MARK: - Per-type extraction

    private func fileItems(from pasteboard: NSPasteboard) -> [ShelfItem]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else { return nil }

        return urls.compactMap { url in
            do {
                return try storage.storeFile(at: url)
            } catch {
                AppLog.error("Failed to store dropped file \(url.lastPathComponent): \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func imageItem(from pasteboard: NSPasteboard) -> ShelfItem? {
        // Prefer PNG, fall back to TIFF — both decode through NSBitmapImageRep.
        let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        guard let data else { return nil }
        do {
            return try storage.storeImageData(data, suggestedName: Self.timestampedImageName())
        } catch {
            AppLog.error("Failed to store dropped image: \(error.localizedDescription)")
            return nil
        }
    }

    private func linkItem(from pasteboard: NSPasteboard) -> ShelfItem? {
        // A web URL arrives as an NSURL that is not a file URL.
        guard let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL,
              !url.isFileURL, url.scheme != nil else { return nil }
        return storage.makeLinkItem(url)
    }

    private func textItem(from pasteboard: NSPasteboard) -> ShelfItem? {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return storage.makeTextItem(text)
    }

    // MARK: - Helpers

    /// A sortable, unique-enough default name for clipboard/pasteboard images.
    private static func timestampedImageName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return "Image-\(formatter.string(from: Date()))"
    }
}
