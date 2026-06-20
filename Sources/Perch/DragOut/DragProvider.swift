import AppKit
import UniformTypeIdentifiers

/// Builds the `NSItemProvider` used to drag a shelf item back out into another
/// app. File-backed items vend a file URL so destinations (Finder, Mail, …)
/// copy the actual file; text/links vend their inline value.
struct DragProvider {
    private let store: ShelfStore

    init(store: ShelfStore) {
        self.store = store
    }

    /// An item provider representing `item`, or `nil` if its backing file has
    /// gone missing.
    @MainActor
    func itemProvider(for item: ShelfItem) -> NSItemProvider? {
        switch item.kind {
        case .file, .image:
            guard let url = store.contentURL(for: item) else { return nil }
            // Vending the file URL lets the destination copy the real file.
            let provider = NSItemProvider()
            let typeID = Self.typeIdentifier(for: url)
            provider.registerFileRepresentation(
                forTypeIdentifier: typeID,
                fileOptions: [],
                visibility: .all
            ) { completion in
                // Hand back the existing stored file directly (no temp copy):
                // `openInPlace: false` tells the system not to move/delete it.
                completion(url, false, nil)
                return nil
            }
            provider.suggestedName = url.lastPathComponent
            return provider

        case .link:
            guard let urlString = item.text, let url = URL(string: urlString) else { return nil }
            return NSItemProvider(object: url as NSURL)

        case .text:
            guard let text = item.text else { return nil }
            return NSItemProvider(object: text as NSString)
        }
    }

    /// Resolves the UTI for a file so the drag advertises the correct type.
    private static func typeIdentifier(for url: URL) -> String {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.identifier
        }
        return UTType.data.identifier
    }
}
