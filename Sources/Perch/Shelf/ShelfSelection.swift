import Combine

/// UI-level selection state for the shelf: which rows are selected for
/// keyboard actions (⌘C copies, Delete removes). Kept separate from
/// `ShelfStore` so the model stays a pure content store.
@MainActor
final class ShelfSelection: ObservableObject {
    @Published private(set) var ids: Set<ShelfItem.ID> = []

    var isEmpty: Bool { ids.isEmpty }

    func contains(_ id: ShelfItem.ID) -> Bool {
        ids.contains(id)
    }

    /// Replaces the selection with a single item (plain click).
    func select(_ id: ShelfItem.ID) {
        ids = [id]
    }

    /// Adds or removes an item from the selection (⌘-click).
    func toggle(_ id: ShelfItem.ID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    func selectAll(_ items: [ShelfItem]) {
        ids = Set(items.map(\.id))
    }

    func clear() {
        ids = []
    }

    /// Drops selected ids whose items no longer exist on the shelf.
    func prune(existing items: [ShelfItem]) {
        let existingIDs = Set(items.map(\.id))
        let pruned = ids.intersection(existingIDs)
        if pruned != ids {
            ids = pruned
        }
    }
}
