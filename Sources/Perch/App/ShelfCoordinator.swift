import AppKit

/// Orchestrates the shelf: ingests drops and clipboard stashes, drives the
/// window and edge trigger, and routes hotkey actions and item interactions.
/// The seam between the UI (SwiftUI shelf, status bar) and the model (stores).
@MainActor
final class ShelfCoordinator {
    let shelfStore: ShelfStore

    private let selection = ShelfSelection()
    private let settingsStore: SettingsStore
    private let storage: ItemStorage
    private let reader: PasteboardReader
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
        self.edgeTrigger = EdgeTriggerController(settingsStore: settingsStore)

        let shelfView = ShelfView(
            store: shelfStore,
            selection: selection,
            onOpen: { [weak self] item in self?.open(item) },
            onRemove: { [weak self] item in self?.remove(item) },
            onClear: { [weak self] in self?.clear() },
            onSelect: { [weak self] item, commandHeld in
                guard let self else { return }
                commandHeld ? self.selection.toggle(item.id) : self.selection.select(item.id)
            }
        )
        self.windowController = ShelfWindowController(settingsStore: settingsStore, shelfView: shelfView)

        windowController.onDrop = { [weak self] pasteboard in
            self?.handleDrop(from: pasteboard) ?? false
        }
        windowController.onKeyCommand = { [weak self] command in
            self?.handle(keyCommand: command) ?? false
        }
        windowController.onPanelResignedKey = { [weak self] in
            self?.selection.clear()
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

    // MARK: - Keyboard commands (shelf panel is key)

    private func handle(keyCommand: ShelfKeyCommand) -> Bool {
        switch keyCommand {
        case .copy:
            copySelection()
        case .paste:
            stashClipboard()
        case .selectAll:
            selection.selectAll(shelfStore.items)
        case .delete:
            removeSelection()
        case .escape:
            // Two-stage: first clear the selection, then dismiss the shelf.
            if selection.isEmpty {
                windowController.hide()
            } else {
                selection.clear()
            }
        }
        return true
    }

    /// Writes the selected items to the general pasteboard, in shelf order.
    /// Files/images vend their real file URLs, so ⌘V in Finder copies the
    /// files; text/links paste as strings/URLs.
    private func copySelection() {
        let selected = shelfStore.items.filter { selection.contains($0.id) }
        let writers = selected.compactMap {
            DragPasteboard.writer(for: $0, contentURL: shelfStore.contentURL(for: $0))
        }
        guard !writers.isEmpty else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(writers)
    }

    private func removeSelection() {
        guard !selection.isEmpty else {
            NSSound.beep()
            return
        }
        shelfStore.remove(ids: selection.ids)
        selection.clear()
        notifyCountChanged()
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
        selection.prune(existing: shelfStore.items)
        notifyCountChanged()
    }

    private func clear() {
        shelfStore.clear()
        selection.clear()
        notifyCountChanged()
    }

    private func notifyCountChanged() {
        onItemsChanged?(shelfStore.count)
    }
}
