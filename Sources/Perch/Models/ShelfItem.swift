import Foundation

/// One thing sitting on the shelf. A pure value type holding metadata only; the
/// actual file bytes (for `.file`/`.image`) live in the item store on disk and
/// are referenced by `storedFilename`. Text and links are stored inline.
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    /// The kind of payload, which determines how the item is drawn and how it is
    /// written back to a drag pasteboard.
    enum Kind: String, Codable, Sendable {
        case file   // a file or folder copied into the store
        case image  // raw image data saved as a file in the store
        case text   // a plain-text snippet, stored inline
        case link   // a URL, stored inline
    }

    let id: UUID
    var kind: Kind
    var title: String
    var addedAt: Date

    /// `.file`/`.image`: the filename of the copied content inside this item's
    /// directory in the store. `nil` for inline kinds.
    var storedFilename: String?

    /// `.text`: the snippet. `.link`: the absolute URL string. `nil` otherwise.
    var text: String?

    /// `.file`: the original source path, kept so the user can reveal the
    /// original in Finder even after it moves on the shelf.
    var originalPath: String?

    /// `.file`/`.image`: size of the stored content in bytes, for display.
    var fileSize: Int64?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        addedAt: Date = Date(),
        storedFilename: String? = nil,
        text: String? = nil,
        originalPath: String? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.addedAt = addedAt
        self.storedFilename = storedFilename
        self.text = text
        self.originalPath = originalPath
        self.fileSize = fileSize
    }

    /// Whether this item's payload is a file on disk (vs. inline text/link).
    var isFileBacked: Bool {
        kind == .file || kind == .image
    }
}
