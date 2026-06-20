import AppKit
import SwiftUI

/// Hosts `SettingsView` in a single reusable window. Subsequent "open settings"
/// requests bring the existing window forward rather than spawning duplicates.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settingsStore: SettingsStore
    private let hotkeys: HotkeyBindingManager

    private let onShelfSettingsChanged: () -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void
    private let onCheckForUpdates: () -> Void

    init(
        settingsStore: SettingsStore,
        hotkeys: HotkeyBindingManager,
        onShelfSettingsChanged: @escaping () -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.hotkeys = hotkeys
        self.onShelfSettingsChanged = onShelfSettingsChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onCheckForUpdates = onCheckForUpdates
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(
            settingsStore: settingsStore,
            hotkeys: hotkeys,
            onShelfSettingsChanged: onShelfSettingsChanged,
            onLaunchAtLoginChanged: onLaunchAtLoginChanged,
            onCheckForUpdates: onCheckForUpdates
        )

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "\(AppInfo.name) 設定"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
