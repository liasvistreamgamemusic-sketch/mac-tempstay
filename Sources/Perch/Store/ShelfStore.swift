import AppKit
import Combine

/// The observable source of truth for the shelf's contents.
///
/// Wraps `ItemStorage` (disk) behind a published `[ShelfItem]` array the SwiftUI
/// shelf renders. Newest items are kept at the top. All mutation flows through
/// here so persistence and the UI never drift apart.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let storage: ItemStorage
    private let settingsStore: SettingsStore

    init(storage: ItemStorage = ItemStorage(), settingsStore: SettingsStore) {
        self.storage = storage
        self.settingsStore = settingsStore
        loadPersistedItems()
    }

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }

    // MARK: - Loading

    private func loadPersistedItems() {
        guard settingsStore.settings.persistItemsAcrossLaunches else {
            // Fresh session requested: drop anything left on disk.
            storage.pruneOrphans(keeping: [])
            storage.saveMetadata([])
            return
        }
        let persisted = storage.loadMetadata()
        // Drop file-backed items whose content went missing (e.g. manual cleanup).
        items = persisted.filter { item in
            !item.isFileBacked || storage.contentURL(for: item) != nil
        }
        storage.pruneOrphans(keeping: items)
        if items.count != persisted.count { persist() }
    }

    // MARK: - Adding

    /// Appends already-built items (deduplicated by id) to the top of the shelf.
    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        let existing = Set(items.map { $0.id })
        let fresh = newItems.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return }
        items.insert(contentsOf: fresh, at: 0)
        persist()
    }

    /// Resolves the absolute on-disk URL for a file-backed item.
    func contentURL(for item: ShelfItem) -> URL? {
        storage.contentURL(for: item)
    }

    // MARK: - Removing

    func remove(_ item: ShelfItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items.remove(at: index)
        storage.remove(item)
        persist()
    }

    func remove(ids: Set<ShelfItem.ID>) {
        guard !ids.isEmpty else { return }
        for item in items where ids.contains(item.id) { storage.remove(item) }
        items.removeAll { ids.contains($0.id) }
        persist()
    }

    func clear() {
        for item in items { storage.remove(item) }
        items.removeAll()
        storage.pruneOrphans(keeping: [])
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        storage.saveMetadata(items)
    }
}
