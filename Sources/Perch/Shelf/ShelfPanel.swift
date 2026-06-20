import AppKit

/// The borderless, floating panel that hosts the shelf. A non-activating panel
/// so dropping onto it never steals focus from the app the user is dragging
/// from — essential for a drag-and-drop shelf.
final class ShelfPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        // Visible across Spaces and over full-screen apps, like other shelves.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    // Borderless panels reject key/main status by default; allow key so text
    // fields (none yet, but future-proof) and buttons inside behave normally.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
