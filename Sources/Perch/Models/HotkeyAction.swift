import AppKit
import Carbon.HIToolbox

/// A global, user-bindable action. Designed to grow: add a case and a default
/// shortcut and the settings UI + binding manager pick it up automatically.
enum HotkeyAction: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Show the shelf if hidden, hide it if visible.
    case toggleShelf
    /// Copy the current clipboard contents onto the shelf as a new item.
    case stashClipboard
    /// Remove every item from the shelf.
    case clearShelf

    var id: String { rawValue }

    /// Human-readable label shown in menus and settings.
    var title: String {
        switch self {
        case .toggleShelf: return "シェルフの表示/非表示"
        case .stashClipboard: return "クリップボードをシェルフへ"
        case .clearShelf: return "シェルフを空にする"
        }
    }

    /// SF Symbol used in the menu and settings rows.
    var symbolName: String {
        switch self {
        case .toggleShelf: return "tray"
        case .stashClipboard: return "doc.on.clipboard"
        case .clearShelf: return "trash"
        }
    }

    /// The shortcut a fresh install ships with. Anchored on ⌃⌥ so they coexist
    /// with text entry and rarely collide with other apps.
    var defaultShortcut: KeyCombo {
        switch self {
        case .toggleShelf:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_V), modifierFlags: [.control, .option])
        case .stashClipboard:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifierFlags: [.control, .option])
        case .clearShelf:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_X), modifierFlags: [.control, .option])
        }
    }
}
