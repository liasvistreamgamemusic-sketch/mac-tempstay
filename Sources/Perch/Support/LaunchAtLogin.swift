import Foundation
import ServiceManagement

/// Wraps `SMAppService` for registering the app as a login item (macOS 13+).
enum LaunchAtLogin {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// `true` only when the item is fully active. `.requiresApproval` (the user
    /// previously disabled it in System Settings, so macOS will not silently
    /// re-enable it) is intentionally *not* "enabled".
    static var isEnabled: Bool {
        status == .enabled
    }

    /// `true` when macOS is waiting for the user to approve the item in System
    /// Settings > General > Login Items. Registering cannot bypass this.
    static var requiresApproval: Bool {
        status == .requiresApproval
    }

    /// Registers or unregisters the login item. A `.requiresApproval` item must
    /// still be unregistered to truly turn it off, otherwise it lingers in Login
    /// Items. Returns whether the call succeeded.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if status != .notRegistered {
                // `unregister()` throws if the item was never registered; only
                // call it when there is actually something to remove.
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            AppLog.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
            return false
        }
    }

    /// Opens System Settings to the Login Items pane so the user can approve a
    /// `.requiresApproval` item.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
