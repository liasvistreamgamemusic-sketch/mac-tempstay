import AppKit
import SwiftUI

/// Owns the shelf panel: builds it, positions it on the configured edge of the
/// screen under the pointer, slides it in/out, and drives auto-hide once the
/// user stops interacting. The single authority on shelf visibility.
@MainActor
final class ShelfWindowController {
    private let settingsStore: SettingsStore
    private let panel: ShelfPanel
    private let container: ShelfContainerView<ShelfView>

    /// Called when a drop is received; returns whether it added anything.
    var onDrop: ((NSPasteboard) -> Bool)?

    private(set) var isVisible = false
    private var isDragInside = false
    private var isPointerInside = false
    private var autoHideWorkItem: DispatchWorkItem?
    /// Suppresses auto-hide while the user explicitly pinned the shelf open
    /// (e.g. summoned by hotkey rather than by a drag).
    private var isPinnedOpen = false

    init(settingsStore: SettingsStore, shelfView: ShelfView) {
        self.settingsStore = settingsStore
        let initialFrame = NSRect(x: 0, y: 0, width: ShelfMetrics.width, height: ShelfMetrics.height)
        self.panel = ShelfPanel(contentRect: initialFrame)
        self.container = ShelfContainerView(rootView: shelfView)
        panel.contentView = container
        wireContainer()
    }

    private func wireContainer() {
        container.onDropPasteboard = { [weak self] pasteboard in
            guard let self else { return false }
            let added = self.onDrop?(pasteboard) ?? false
            // Keep the shelf up briefly after a successful drop.
            self.isDragInside = false
            self.scheduleAutoHideIfNeeded()
            return added
        }
        container.onDragStateChange = { [weak self] dragging in
            guard let self else { return }
            self.isDragInside = dragging
            if dragging {
                self.cancelAutoHide()
            } else {
                self.scheduleAutoHideIfNeeded()
            }
        }
        container.onPointerInside = { [weak self] inside in
            guard let self else { return }
            self.isPointerInside = inside
            if inside {
                self.cancelAutoHide()
            } else {
                self.scheduleAutoHideIfNeeded()
            }
        }
    }

    // MARK: - Visibility

    func toggle() {
        if isVisible { hide() } else { show(pinned: true) }
    }

    /// Shows the shelf, sliding it in from the docked edge.
    /// - Parameter pinned: when `true` (hotkey/menu summon) the shelf stays open
    ///   until dismissed; when `false` (revealed by an approaching drag) it
    ///   auto-hides once the drag/pointer leaves.
    func show(pinned: Bool) {
        isPinnedOpen = isPinnedOpen || pinned
        cancelAutoHide()

        let screen = targetScreenFrame()
        let edge = settingsStore.settings.edge
        let size = CGSize(width: ShelfMetrics.width, height: ShelfMetrics.height)
        let shownFrame = edge.shelfFrame(size: size, on: screen, gap: ShelfMetrics.edgeGap)

        if !isVisible {
            panel.setFrame(edge.hiddenFrame(size: size, on: screen), display: false)
            panel.orderFrontRegardless()
        }
        isVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shownFrame, display: true)
        }

        if !pinned { scheduleAutoHideIfNeeded() }
    }

    func hide() {
        guard isVisible else { return }
        cancelAutoHide()
        isPinnedOpen = false

        let screen = targetScreenFrame()
        let edge = settingsStore.settings.edge
        let size = CGSize(width: ShelfMetrics.width, height: ShelfMetrics.height)
        let hidden = edge.hiddenFrame(size: size, on: screen)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hidden, display: true)
        } completionHandler: { [weak self] in
            // The completion handler fires on the main thread; hop into the
            // actor explicitly so the isolated state can be mutated safely.
            MainActor.assumeIsolated {
                self?.panel.orderOut(nil)
                self?.isVisible = false
            }
        }
    }

    /// Reveals the shelf in response to an approaching drag (not pinned).
    func revealForIncomingDrag() {
        guard settingsStore.settings.revealOnDragToEdge, !isVisible else { return }
        show(pinned: false)
    }

    /// Re-applies the docked position after the edge preference changes.
    func repositionForCurrentEdge() {
        guard isVisible else { return }
        let screen = targetScreenFrame()
        let edge = settingsStore.settings.edge
        let size = CGSize(width: ShelfMetrics.width, height: ShelfMetrics.height)
        panel.animator().setFrame(edge.shelfFrame(size: size, on: screen, gap: ShelfMetrics.edgeGap), display: true)
    }

    // MARK: - Auto-hide

    private func scheduleAutoHideIfNeeded() {
        cancelAutoHide()
        guard settingsStore.settings.autoHide, isVisible, !isPinnedOpen else { return }
        guard !isDragInside, !isPointerInside else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isDragInside, !self.isPointerInside, !self.isPinnedOpen else { return }
            self.hide()
        }
        autoHideWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settingsStore.settings.autoHideDelay,
            execute: work
        )
    }

    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }

    // MARK: - Geometry

    /// The visible frame of the screen currently containing the pointer, so the
    /// shelf appears where the user is working (multi-display aware).
    private func targetScreenFrame() -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
        return screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
