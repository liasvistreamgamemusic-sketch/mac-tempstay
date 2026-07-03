import AppKit

/// Keyboard commands the shelf panel recognises while it is the key window.
enum ShelfKeyCommand {
    case copy
    case paste
    case selectAll
    case delete
    case escape
}

/// The borderless, floating panel that hosts the shelf. A non-activating panel
/// so dropping onto it never steals focus from the app the user is dragging
/// from — essential for a drag-and-drop shelf.
final class ShelfPanel: NSPanel {
    /// Handles a keyboard command; returns whether the event was consumed.
    var onKeyCommand: ((ShelfKeyCommand) -> Bool)?

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

    // MARK: - Focus & keyboard

    // Non-activating panels don't take key status on click; grab it explicitly
    // so the shelf is "focused" once the user clicks it. Drops arrive through
    // NSDraggingDestination callbacks (never a mouseDown here), so the
    // no-focus-steal drag-and-drop behaviour is untouched.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }

    // ⌘-shortcuts arrive here while the panel is key. There is no main menu in
    // this accessory app, so Copy/Paste must be handled at the window level.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let key = event.charactersIgnoringModifiers?.lowercased() {
            let command: ShelfKeyCommand?
            switch key {
            case "c": command = .copy
            case "v": command = .paste
            case "a": command = .selectAll
            default: command = nil
            }
            if let command, onKeyCommand?(command) == true {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let command: ShelfKeyCommand?
        switch event.keyCode {
        case 53: command = .escape          // esc
        case 51, 117: command = .delete     // delete / forward delete
        default: command = nil
        }
        if let command, onKeyCommand?(command) == true {
            return
        }
        super.keyDown(with: event)
    }
}
