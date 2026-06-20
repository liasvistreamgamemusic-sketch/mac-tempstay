import AppKit

/// Positions the `EdgeTriggerWindow` along the configured screen edge and keeps
/// it in sync with the edge preference, the "reveal on drag" toggle, and screen
/// changes. Reveals the shelf when a drag approaches.
@MainActor
final class EdgeTriggerController {
    private let settingsStore: SettingsStore
    private let window = EdgeTriggerWindow()

    /// Invoked when a drag approaches the edge and the shelf should appear.
    var onApproach: (() -> Void)?

    /// Width of the drag-sensing strip.
    private let stripWidth: CGFloat = 6
    /// Fraction of the screen height the strip covers, centred vertically — the
    /// band where the shelf lives.
    private let coverageFraction: CGFloat = 0.6

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        window.onDragApproach = { [weak self] in self?.onApproach?() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        apply()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Re-evaluates whether the strip should be shown and where, from current
    /// settings. Call after the edge or reveal preference changes.
    func apply() {
        guard settingsStore.settings.revealOnDragToEdge else {
            window.orderOut(nil)
            return
        }
        reposition()
        window.orderFrontRegardless()
    }

    private func reposition() {
        guard let screen = NSScreen.main?.frame else { return }
        let height = screen.height * coverageFraction
        let y = screen.midY - height / 2
        let edge = settingsStore.settings.edge

        let x: CGFloat
        switch edge {
        case .left:
            x = screen.minX
        case .right:
            x = screen.maxX - stripWidth
        }
        window.setFrame(CGRect(x: x, y: y, width: stripWidth, height: height), display: false)
    }

    @objc private func screensChanged() {
        if settingsStore.settings.revealOnDragToEdge { reposition() }
    }
}
