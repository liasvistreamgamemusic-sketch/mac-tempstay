import Foundation

/// All user-configurable preferences, persisted as a single JSON blob.
/// Versioned implicitly by `SettingsStore`'s storage key; add fields with
/// sensible defaults so older payloads decode cleanly.
struct AppSettings: Codable, Equatable, Sendable {
    /// Global shortcuts keyed by action. Missing entries fall back to the
    /// action's `defaultShortcut`, so a new action is bound out of the box.
    var shortcuts: [HotkeyAction: KeyCombo]

    /// Which screen edge the shelf docks to.
    var edge: ShelfEdge

    /// Reveal the shelf automatically when a drag approaches the docked edge.
    var revealOnDragToEdge: Bool

    /// Auto-hide the shelf shortly after a drag finishes / the pointer leaves it.
    var autoHide: Bool

    /// Seconds the shelf waits before auto-hiding once the pointer leaves it.
    var autoHideDelay: Double

    /// Launch Perch automatically when the user logs in.
    var launchAtLogin: Bool

    /// Keep shelf items on disk across app launches (vs. clearing on quit).
    var persistItemsAcrossLaunches: Bool

    /// A release tag the user chose to skip in the updater. Empty when none.
    var skippedUpdateVersion: String

    static let `default` = AppSettings(
        shortcuts: Dictionary(uniqueKeysWithValues: HotkeyAction.allCases.map { ($0, $0.defaultShortcut) }),
        edge: .right,
        revealOnDragToEdge: true,
        autoHide: true,
        autoHideDelay: 1.5,
        launchAtLogin: false,
        persistItemsAcrossLaunches: true,
        skippedUpdateVersion: ""
    )

    /// The shortcut bound to `action`, falling back to its default when unset.
    func shortcut(for action: HotkeyAction) -> KeyCombo {
        shortcuts[action] ?? action.defaultShortcut
    }
}
