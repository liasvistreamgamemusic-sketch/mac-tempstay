import AppKit

/// Orchestrates the shelf: ingests drops and clipboard stashes, drives the
/// window and edge trigger, and routes hotkey actions and item interactions.
/// The seam between the UI (SwiftUI shelf, status bar) and the model (stores).
@MainActor
final class ShelfCoordinator {
    let shelfStore: ShelfStore

    private let settingsStore: SettingsStore
    private let storage: ItemStorage
    private let reader: PasteboardReader
    private let dragProvider: DragProvider
    private let edgeTrigger: EdgeTriggerController
    private var windowController: ShelfWindowController!

    /// Notifies observers (e.g. the status item) that the item count changed.
    var onItemsChanged: ((Int) -> Void)?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let storage = ItemStorage()
        self.storage = storage
        self.shelfStore = ShelfStore(storage: storage, settingsStore: settingsStore)
        self.reader = PasteboardReader(storage: storage)
        self.dragProvider = DragProvider(store: shelfStore)
        self.edgeTrigger = EdgeTriggerController(settingsStore: settingsStore)

        let shelfView = ShelfView(
            store: shelfStore,
            makeProvider: { [weak self] item in self?.dragProvider.itemProvider(for: item) },
            onOpen: { [weak self] item in self?.open(item) },
            onRemove: { [weak self] item in self?.remove(item) },
            onClear: { [weak self] in self?.clear() }
        )
        self.windowController = ShelfWindowController(settingsStore: settingsStore, shelfView: shelfView)

        windowController.onDrop = { [weak self] pasteboard in
            self?.handleDrop(from: pasteboard) ?? false
        }
        edgeTrigger.onApproach = { [weak self] in
            self?.windowController.revealForIncomingDrag()
        }
    }

    // MARK: - Hotkey actions

    func handle(_ action: HotkeyAction) {
        switch action {
        case .toggleShelf: windowController.toggle()
        case .stashClipboard: stashClipboard()
        case .clearShelf: clear()
        }
    }

    /// Re-applies settings-derived state (edge position, reveal toggle).
    func settingsChanged() {
        edgeTrigger.apply()
        windowController.repositionForCurrentEdge()
    }

    // MARK: - Ingestion

    /// Reads a drop's pasteboard and adds the resulting items. Returns whether
    /// anything was added.
    private func handleDrop(from pasteboard: NSPasteboard) -> Bool {
        let items = reader.items(from: pasteboard)
        guard !items.isEmpty else { return false }
        shelfStore.add(items)
        notifyCountChanged()
        return true
    }

    private func stashClipboard() {
        let items = reader.items(from: .general)
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        shelfStore.add(items)
        notifyCountChanged()
        windowController.show(pinned: true)
    }

    // MARK: - Item interactions

    private func open(_ item: ShelfItem) {
        switch item.kind {
        case .file, .image:
            if let url = shelfStore.contentURL(for: item) {
                NSWorkspace.shared.open(url)
            }
        case .link:
            if let text = item.text, let url = URL(string: text) {
                NSWorkspace.shared.open(url)
            }
        case .text:
            // Nothing to open for a snippet; copy it back to the clipboard.
            if let text = item.text {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    private func remove(_ item: ShelfItem) {
        shelfStore.remove(item)
        notifyCountChanged()
    }

    private func clear() {
        shelfStore.clear()
        notifyCountChanged()
    }

    private func notifyCountChanged() {
        onItemsChanged?(shelfStore.count)
    }
}
