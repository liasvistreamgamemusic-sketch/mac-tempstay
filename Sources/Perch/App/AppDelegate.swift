import AppKit

/// Application lifecycle owner. Constructs and wires every subsystem — settings,
/// the shelf coordinator, global hotkeys, the menu bar item, and the updater —
/// and keeps the login item in sync with the preference.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private lazy var coordinator = ShelfCoordinator(settingsStore: settingsStore)
    private lazy var hotkeys = HotkeyBindingManager(settingsStore: settingsStore)
    private lazy var statusItem = StatusItemController(settingsStore: settingsStore)
    private lazy var updater = AppUpdater(settingsStore: settingsStore)
    private lazy var settingsWindow = SettingsWindowController(
        settingsStore: settingsStore,
        hotkeys: hotkeys,
        onShelfSettingsChanged: { [weak self] in self?.coordinator.settingsChanged() },
        onLaunchAtLoginChanged: { [weak self] enabled in self?.applyLaunchAtLogin(enabled) },
        onCheckForUpdates: { [weak self] in self?.checkForUpdates(userInitiated: true) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar agent only — no Dock icon (also set via LSUIElement).
        NSApp.setActivationPolicy(.accessory)

        wireHotkeys()
        wireStatusItem()
        syncLaunchAtLoginState()

        // Background update check on launch — silent unless something is new.
        checkForUpdates(userInitiated: false)

        AppLog.info("\(AppInfo.name) \(AppInfo.version) launched")
    }

    // MARK: - Wiring

    private func wireHotkeys() {
        hotkeys.onTrigger = { [weak self] action in
            self?.coordinator.handle(action)
        }
        hotkeys.refresh()
    }

    private func wireStatusItem() {
        statusItem.onAction = { [weak self] action in self?.coordinator.handle(action) }
        statusItem.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.onCheckForUpdates = { [weak self] in self?.checkForUpdates(userInitiated: true) }
        statusItem.onQuit = { NSApp.terminate(nil) }

        coordinator.onItemsChanged = { [weak self] count in
            self?.statusItem.updateItemCount(count)
        }
        // Reflect any persisted items in the menu bar glyph at launch.
        statusItem.updateItemCount(coordinator.shelfStore.count)
    }

    // MARK: - Login item

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let ok = LaunchAtLogin.setEnabled(enabled)
        if !ok {
            // Revert the stored preference if the system call failed.
            settingsStore.update { $0.launchAtLogin = LaunchAtLogin.isEnabled }
        }
    }

    /// Reconcile the stored preference with the actual system state at launch
    /// (the user may have toggled it in System Settings).
    private func syncLaunchAtLoginState() {
        let actual = LaunchAtLogin.isEnabled
        if settingsStore.settings.launchAtLogin != actual {
            settingsStore.update { $0.launchAtLogin = actual }
        }
    }

    // MARK: - Updates

    private func checkForUpdates(userInitiated: Bool) {
        // Skip background auto-checks when running unpackaged (`swift run`).
        guard userInitiated || AppInfo.isRunningFromBundle else { return }
        Task { await updater.checkForUpdates(userInitiated: userInitiated) }
    }
}
