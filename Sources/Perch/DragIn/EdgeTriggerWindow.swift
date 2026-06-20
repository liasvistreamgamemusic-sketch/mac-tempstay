import AppKit

/// A thin, transparent strip docked to the screen edge whose only job is to
/// notice a drag approaching and reveal the shelf — the "drag to the edge to
/// summon" gesture. It is a drag destination but holds no content.
///
/// Because macOS only routes a drag into a window it can hit-test, the strip
/// cannot be fully click-through; it is kept narrow and limited to the vertical
/// band where the shelf appears to minimise interference with the screen edge.
final class EdgeTriggerWindow: NSPanel {
    /// Fired when a drag enters the strip.
    var onDragApproach: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false // must participate in drag hit-testing

        let view = TriggerView()
        view.onDragApproach = { [weak self] in self?.onDragApproach?() }
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Swallow plain clicks silently rather than acting on the edge strip.
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
}

/// The strip's content view: an invisible drag destination.
private final class TriggerView: NSView {
    var onDragApproach: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(PasteboardReader.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragApproach?()
        // Return .generic (not .copy) — the strip only reveals the shelf; the
        // actual drop should happen on the shelf itself, not this sliver.
        return []
    }
}
