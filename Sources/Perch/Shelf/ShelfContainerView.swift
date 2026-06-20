import AppKit
import SwiftUI

/// The panel's content view and drag-in destination. It hosts the SwiftUI
/// `ShelfView` filling its bounds and accepts drags by reading the dragging
/// pasteboard directly — far simpler and more complete than per-provider
/// SwiftUI `.onDrop` handling for file URLs, images, links and text together.
final class ShelfContainerView<Content: View>: NSView {
    /// Invoked when something is dropped; returns whether the drop produced
    /// any items (so the controller can flash feedback / keep the shelf open).
    var onDropPasteboard: ((NSPasteboard) -> Bool)?
    /// Notifies the controller that a drag entered/left, to drive auto-hide.
    var onDragStateChange: ((Bool) -> Void)?
    /// Notifies the controller that the pointer entered/left the shelf, to drive
    /// auto-hide once the user is no longer interacting with it.
    var onPointerInside: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private let hostingView: NSHostingView<Content>

    init(rootView: Content) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        registerForDraggedTypes(PasteboardReader.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setRootView(_ rootView: Content) {
        hostingView.rootView = rootView
    }

    // MARK: - Pointer tracking (auto-hide)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onPointerInside?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onPointerInside?(false)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragStateChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragStateChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragStateChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropPasteboard?(sender.draggingPasteboard) ?? false
    }
}
