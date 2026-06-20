import AppKit
import UniformTypeIdentifiers

/// Owns the on-disk home for shelf content under Application Support.
///
/// File-backed items (`.file`/`.image`) get their own subdirectory
/// (`Items/<uuid>/<filename>`) so original names are preserved without
/// collisions. Item metadata is persisted as one `items.json`. Text/link items
/// carry their payload inline and touch no files.
///
/// Files are *copied* in (not referenced) so the shelf keeps working after the
/// user moves or deletes the original — the same guarantee Yoink-style shelves
/// give.
final class ItemStorage {
    enum StorageError: LocalizedError {
        case unreadableSource(URL)
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableSource(let url): return "ファイルを読み込めませんでした: \(url.lastPathComponent)"
            case .encodingFailed: return "アイテムの保存に失敗しました。"
            }
        }
    }

    private let fileManager: FileManager
    private let rootURL: URL
    private let itemsURL: URL
    private let metadataURL: URL

    /// - Parameter rootOverride: when provided, content is stored here instead
    ///   of Application Support — used by tests to stay off the real user dir.
    init(fileManager: FileManager = .default, rootOverride: URL? = nil) {
        self.fileManager = fileManager
        let base: URL
        if let rootOverride {
            base = rootOverride
        } else {
            base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
        }
        self.rootURL = base.appendingPathComponent(AppInfo.name, isDirectory: true)
        self.itemsURL = rootURL.appendingPathComponent("Items", isDirectory: true)
        self.metadataURL = rootURL.appendingPathComponent("items.json", isDirectory: false)
        ensureDirectories()
    }

    // MARK: - Directory layout

    private func ensureDirectories() {
        for url in [rootURL, itemsURL] {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                AppLog.error("Failed to create storage directory \(url.path): \(error.localizedDescription)")
            }
        }
    }

    private func directory(for id: UUID) -> URL {
        itemsURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Absolute URL of the stored content for a file-backed item, or `nil` for
    /// inline (text/link) items or if the file is missing.
    func contentURL(for item: ShelfItem) -> URL? {
        guard let filename = item.storedFilename else { return nil }
        let url = directory(for: item.id).appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Ingesting content

    /// Copies a file or folder into the store and returns the resulting item.
    func storeFile(at source: URL) throws -> ShelfItem {
        guard fileManager.fileExists(atPath: source.path) else {
            throw StorageError.unreadableSource(source)
        }
        let id = UUID()
        let dir = directory(for: id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = source.lastPathComponent
        let destination = dir.appendingPathComponent(filename)
        try fileManager.copyItem(at: source, to: destination)

        let isImage = (try? source.resourceValues(forKeys: [.contentTypeKey]))?
            .contentType?.conforms(to: .image) ?? false

        return ShelfItem(
            id: id,
            kind: isImage ? .image : .file,
            title: filename,
            storedFilename: filename,
            originalPath: source.path,
            fileSize: byteSize(of: destination)
        )
    }

    /// Saves raw image data (e.g. from the pasteboard) as a PNG-backed item.
    func storeImageData(_ data: Data, suggestedName: String) throws -> ShelfItem {
        let id = UUID()
        let dir = directory(for: id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = suggestedName.hasSuffix(".png") ? suggestedName : "\(suggestedName).png"
        let destination = dir.appendingPathComponent(filename)
        // Normalise whatever bitmap we were given to PNG for a stable file.
        guard let png = Self.pngData(from: data) else { throw StorageError.encodingFailed }
        try png.write(to: destination)

        return ShelfItem(
            id: id,
            kind: .image,
            title: filename,
            storedFilename: filename,
            fileSize: byteSize(of: destination)
        )
    }

    /// Builds an inline text item (no file written).
    func makeTextItem(_ text: String) -> ShelfItem {
        ShelfItem(kind: .text, title: Self.previewTitle(for: text), text: text)
    }

    /// Builds an inline link item (no file written).
    func makeLinkItem(_ url: URL) -> ShelfItem {
        ShelfItem(kind: .link, title: url.absoluteString, text: url.absoluteString)
    }

    // MARK: - Removal

    func remove(_ item: ShelfItem) {
        guard item.isFileBacked else { return }
        let dir = directory(for: item.id)
        guard fileManager.fileExists(atPath: dir.path) else { return }
        do {
            try fileManager.removeItem(at: dir)
        } catch {
            AppLog.error("Failed to remove item \(item.id): \(error.localizedDescription)")
        }
    }

    /// Removes any item directories not referenced by `keep` — used to reclaim
    /// space after items are cleared or fail to decode.
    func pruneOrphans(keeping keep: [ShelfItem]) {
        let liveIDs = Set(keep.map { $0.id.uuidString })
        guard let entries = try? fileManager.contentsOfDirectory(
            at: itemsURL, includingPropertiesForKeys: nil) else { return }
        for entry in entries where !liveIDs.contains(entry.lastPathComponent) {
            try? fileManager.removeItem(at: entry)
        }
    }

    // MARK: - Metadata persistence

    func loadMetadata() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: metadataURL) else { return [] }
        do {
            return try JSONDecoder().decode([ShelfItem].self, from: data)
        } catch {
            AppLog.error("Failed to decode item metadata: \(error.localizedDescription)")
            return []
        }
    }

    func saveMetadata(_ items: [ShelfItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            AppLog.error("Failed to save item metadata: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func byteSize(of url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
        if let size = values?.totalFileAllocatedSize ?? values?.fileSize { return Int64(size) }
        return nil
    }

    /// Re-encodes arbitrary bitmap data as PNG. Returns `nil` if undecodable.
    private static func pngData(from data: Data) -> Data? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// A short single-line title for a text snippet.
    private static func previewTitle(for text: String, limit: Int = 40) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "テキスト" }
        return trimmed.count > limit ? String(trimmed.prefix(limit)) + "…" : trimmed
    }
}
