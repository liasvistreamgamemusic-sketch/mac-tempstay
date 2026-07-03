import AppKit
import SwiftUI

/// A shelf row that drags out as a *real file* (`public.file-url`).
///
/// SwiftUI's `.onDrag` vends an `NSItemProvider`, which the system bridges into
/// a file *promise* drag. Native apps (Finder, Mail) honour promises, but
/// Electron/web targets (Teams, Slack, VS Code) do not — they only read an
/// actual file URL, so a promised file shows up as text or not at all. To make
/// files droppable everywhere, this view bypasses `.onDrag` and acts as an
/// AppKit `NSDraggingSource`, vending the file URL directly via
/// `DragPasteboard.writer(for:contentURL:)`.
struct DraggableItemView: NSViewRepresentable {
    let item: ShelfItem
    let contentURL: URL?
    /// Whether the row is part of the shelf's current selection.
    let isSelected: Bool
    /// Open / preview the item (double-click).
    let onOpen: () -> Void
    /// Remove the item (hover delete button).
    let onRemove: () -> Void
    /// Select the item (single click); the Bool is whether ⌘ was held.
    let onSelect: (Bool) -> Void

    func makeNSView(context: Context) -> DraggingSourceView {
        let view = DraggingSourceView()
        view.update(
            item: item,
            contentURL: contentURL,
            isSelected: isSelected,
            onOpen: onOpen,
            onRemove: onRemove,
            onSelect: onSelect
        )
        return view
    }

    func updateNSView(_ nsView: DraggingSourceView, context: Context) {
        nsView.update(
            item: item,
            contentURL: contentURL,
            isSelected: isSelected,
            onOpen: onOpen,
            onRemove: onRemove,
            onSelect: onSelect
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DraggingSourceView, context: Context) -> CGSize? {
        nsView.fittingSize(forWidth: proposal.width ?? ShelfMetrics.width)
    }
}

/// AppKit drag source backing `DraggableItemView`.
///
/// Renders the row via a (non-interactive) hosting view and handles all input
/// itself: double-click opens, a hover delete button removes, and a drag past a
/// small threshold begins a file/text drag session.
final class DraggingSourceView: NSView, NSDraggingSource {
    /// Pointer travel (in points, squared) before a press becomes a drag.
    private static let dragThresholdSquared: CGFloat = 16

    private let hostingView = PassthroughHostingView(rootView: AnyView(EmptyView()))
    private let deleteButton = NSButton()

    private var item: ShelfItem?
    private var contentURL: URL?
    private var isSelected = false
    private var onOpen: () -> Void = {}
    private var onRemove: () -> Void = {}
    private var onSelect: (Bool) -> Void = { _ in }

    private var isHovering = false
    private var pressOrigin: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupSubviews() {
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isBordered = false
        deleteButton.imagePosition = .imageOnly
        deleteButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "削除")
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.target = self
        deleteButton.action = #selector(removeTapped)
        deleteButton.toolTip = "削除"
        deleteButton.isHidden = true
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// Re-applies the item, content URL, selection and callbacks, re-rendering
    /// the row.
    func update(
        item: ShelfItem,
        contentURL: URL?,
        isSelected: Bool,
        onOpen: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onSelect: @escaping (Bool) -> Void
    ) {
        self.item = item
        self.contentURL = contentURL
        self.isSelected = isSelected
        self.onOpen = onOpen
        self.onRemove = onRemove
        self.onSelect = onSelect
        renderContent()
    }

    private func renderContent() {
        guard let item else { return }
        hostingView.rootView = AnyView(
            ShelfItemRowContent(
                item: item,
                contentURL: contentURL,
                isHovering: isHovering,
                isSelected: isSelected
            )
        )
    }

    /// The row's fitting size for a proposed width (height is fixed: rows are
    /// single-line, so the hosting view's fitting height is width-independent).
    func fittingSize(forWidth width: CGFloat) -> CGSize {
        CGSize(width: width, height: hostingView.fittingSize.height)
    }

    // MARK: - Hover (delete button + row highlight)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    private func setHovering(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        deleteButton.isHidden = !hovering
        renderContent()
    }

    @objc private func removeTapped() {
        onRemove()
    }

    // MARK: - Click / drag

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            pressOrigin = nil
            onOpen()
            return
        }
        // Select on mouse-down (Finder-style) so a drag-out also visibly acts
        // on a selected row; ⌘-click toggles membership instead.
        onSelect(event.modifierFlags.contains(.command))
        pressOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = pressOrigin else { return }
        let dx = event.locationInWindow.x - origin.x
        let dy = event.locationInWindow.y - origin.y
        guard (dx * dx + dy * dy) >= Self.dragThresholdSquared else { return }
        pressOrigin = nil
        beginDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        pressOrigin = nil
    }

    private func beginDrag(with event: NSEvent) {
        guard let item, let writer = DragPasteboard.writer(for: item, contentURL: contentURL) else {
            NSSound.beep()
            return
        }
        let image = ItemThumbnail.image(for: item, contentURL: contentURL, side: ShelfMetrics.thumbnailSide)
        let location = convert(event.locationInWindow, from: nil)
        let frame = NSRect(
            x: location.x - image.size.width / 2,
            y: location.y - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        draggingItem.setDraggingFrame(frame, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}

/// A hosting view that renders SwiftUI content but lets every mouse event fall
/// through to its superview, so `DraggingSourceView` owns click and drag input.
private final class PassthroughHostingView: NSHostingView<AnyView> {
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
