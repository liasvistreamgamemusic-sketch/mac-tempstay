import AppKit

/// Owns the menu bar status item — the app's "header" — including its icon
/// (which reflects whether the shelf has items) and the dropdown menu of
/// actions: summon the shelf, run each bound action, open settings, quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// Callbacks wired up by the app delegate.
    var onAction: ((HotkeyAction) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let settingsStore: SettingsStore
    private var itemCount = 0

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        statusItem.menu = buildMenu()
    }

    /// Updates the menu bar glyph to reflect whether the shelf holds anything.
    func updateItemCount(_ count: Int) {
        itemCount = count
        guard let button = statusItem.button else { return }
        button.image = AppIconFactory.statusBarImage(itemCount: count)
        button.image?.isTemplate = true
    }

    // MARK: - Status button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = AppIconFactory.statusBarImage(itemCount: 0)
        button.image?.isTemplate = true
        button.toolTip = "\(AppInfo.name) — ドラッグ用の一時シェルフ"
        button.setAccessibilityLabel(AppInfo.name)
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "\(AppInfo.name) \(AppInfo.version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for action in HotkeyAction.allCases {
            menu.addItem(actionItem(for: action))
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "アップデートを確認…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let aboutItem = NSMenuItem(title: "\(AppInfo.name) について", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "\(AppInfo.name) を終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func actionItem(for action: HotkeyAction) -> NSMenuItem {
        let item = NSMenuItem(title: action.title, action: #selector(performAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action.rawValue
        item.image = NSImage(systemSymbolName: action.symbolName, accessibilityDescription: action.title)

        let combo = settingsStore.shortcut(for: action)
        if let key = ShortcutGlyph.keyEquivalent(for: combo) {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = combo.modifierFlags
        }
        return item
    }

    // MARK: - Actions

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = HotkeyAction(rawValue: raw) else { return }
        onAction?(action)
    }

    @objc private func openSettings() { onOpenSettings?() }

    @objc private func checkForUpdates() { onCheckForUpdates?() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: "\(AppInfo.version) (\(AppInfo.build))"
        ])
    }

    @objc private func quit() { onQuit?() }
}

/// Maps a `KeyCombo` to the single-character `keyEquivalent` NSMenu expects, so
/// the menu renders the shortcut glyphs natively.
enum ShortcutGlyph {
    static func keyEquivalent(for combo: KeyCombo) -> String? {
        guard let char = TISKeyTranslator.character(for: combo.keyCode), !char.isEmpty else { return nil }
        return char.lowercased()
    }
}
