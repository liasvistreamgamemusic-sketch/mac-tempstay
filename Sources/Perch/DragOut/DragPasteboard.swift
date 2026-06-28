import AppKit

/// Builds the pasteboard writer used to drag a shelf item back out into another
/// app.
///
/// File-backed items vend the **real file URL** (`public.file-url`) so any
/// destination — including Electron/web drop targets like Teams, Slack and
/// VS Code — receives an actual file rather than a file *promise* (which those
/// apps silently ignore, falling back to a text representation).
enum DragPasteboard {
    /// A pasteboard writer representing `item`, or `nil` when there is nothing
    /// to vend (e.g. its backing file has gone missing).
    ///
    /// - Parameters:
    ///   - item: the shelf item being dragged out.
    ///   - contentURL: the on-disk URL for file/image items (see
    ///     `ShelfStore.contentURL(for:)`); ignored for text/link items.
    static func writer(for item: ShelfItem, contentURL: URL?) -> NSPasteboardWriting? {
        switch item.kind {
        case .file, .image:
            // The file already lives in the store; vend its URL directly so the
            // destination copies the real file. `NSURL` writes `public.file-url`.
            guard let url = contentURL else { return nil }
            return url as NSURL

        case .link:
            guard let urlString = item.text, let url = URL(string: urlString) else { return nil }
            return url as NSURL

        case .text:
            guard let text = item.text else { return nil }
            return text as NSString
        }
    }
}
