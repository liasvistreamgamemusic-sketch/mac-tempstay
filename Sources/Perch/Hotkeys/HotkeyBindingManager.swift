import Combine
import Foundation

/// Bridges `SettingsStore` shortcuts to the low-level `HotkeyCenter`,
/// re-registering whenever the bindings change so the two stay in sync.
@MainActor
final class HotkeyBindingManager: ObservableObject {
    private let center = HotkeyCenter()
    private let settingsStore: SettingsStore
    private var lastBoundShortcuts: [HotkeyAction: KeyCombo] = [:]

    /// Actions whose shortcut could not be registered (e.g. taken by another app
    /// or the system). Published so the settings UI can warn instead of failing
    /// silently.
    @Published private(set) var unboundActions: Set<HotkeyAction> = []

    /// Invoked when a bound shortcut fires.
    var onTrigger: ((HotkeyAction) -> Void)?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    /// (Re)binds all shortcuts from current settings. Idempotent — only does
    /// work when the bindings actually changed.
    func refresh() {
        let shortcuts = Dictionary(
            uniqueKeysWithValues: HotkeyAction.allCases.map { ($0, settingsStore.shortcut(for: $0)) }
        )
        guard shortcuts != lastBoundShortcuts else { return }
        lastBoundShortcuts = shortcuts

        center.unregisterAll()
        var failed: Set<HotkeyAction> = []
        for action in HotkeyAction.allCases {
            let combo = shortcuts[action] ?? action.defaultShortcut
            guard combo.isValid else {
                AppLog.error("Invalid shortcut for \(action.rawValue): \(combo.displayString)")
                failed.insert(action)
                continue
            }
            let didRegister = center.register(combo) { [weak self] in
                self?.onTrigger?(action)
            }
            if !didRegister {
                AppLog.error("Could not bind \(action.rawValue) to \(combo.displayString) (already in use?)")
                failed.insert(action)
            }
        }
        unboundActions = failed
    }
}
