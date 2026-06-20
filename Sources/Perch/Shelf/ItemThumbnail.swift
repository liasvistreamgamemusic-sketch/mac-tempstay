import AppKit

/// Produces a display thumbnail for a shelf item: the real image for `.image`,
/// the file-type icon for `.file`, and an SF Symbol for inline `.text`/`.link`.
/// Kept lightweight and synchronous — shelves hold a handful of items, not a
/// gallery, so eager thumbnailing is fine.
enum ItemThumbnail {
    static func image(for item: ShelfItem, contentURL: URL?, side: CGFloat) -> NSImage {
        switch item.kind {
        case .image:
            if let url = contentURL, let image = NSImage(contentsOf: url) {
                return image
            }
            return symbol("photo", side: side)

        case .file:
            if let url = contentURL {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: side, height: side)
                return icon
            }
            return symbol("doc", side: side)

        case .text:
            return symbol("doc.plaintext", side: side)

        case .link:
            return symbol("link", side: side)
        }
    }

    private static func symbol(_ name: String, side: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: side * 0.6, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        return image ?? NSImage(size: NSSize(width: side, height: side))
    }
}

/// Formatting helpers shared by the shelf UI.
enum ItemFormat {
    static func byteString(_ size: Int64?) -> String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func subtitle(for item: ShelfItem) -> String? {
        switch item.kind {
        case .file, .image:
            return byteString(item.fileSize)
        case .link:
            return item.text
        case .text:
            return nil
        }
    }
}
