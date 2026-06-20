import AppKit
import Carbon.HIToolbox

/// A persistable global shortcut: a virtual key code plus Cocoa modifier flags.
/// Stored in settings and translated to Carbon modifiers at registration time.
struct KeyCombo: Codable, Equatable, Sendable {
    /// `kVK_*` virtual key code (hardware independent).
    var keyCode: UInt32
    /// Raw value of `NSEvent.ModifierFlags` restricted to the device-independent set.
    var modifierFlagsRawValue: UInt

    /// The only modifiers meaningful for a global shortcut. Caps Lock, Fn, etc.
    /// are deliberately excluded.
    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
            .intersection(Self.relevantModifiers)
    }

    init(keyCode: UInt32, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlagsRawValue = modifierFlags
            .intersection(Self.relevantModifiers).rawValue
    }

    /// Modifiers that make a global shortcut reliable. A combo must include at
    /// least one of these: Option/Shift-only combos clash with text entry and are
    /// easily mis-recorded (e.g. ⌥⇧A instead of the intended ⌃⌥S).
    static let requiredAnchors: NSEvent.ModifierFlags = [.command, .control]

    /// A global shortcut is valid when it carries Command or Control.
    var isValid: Bool {
        !modifierFlags.isDisjoint(with: Self.requiredAnchors)
    }

    /// Human-readable representation, e.g. `⌃⌥⌘R`.
    var displayString: String {
        Self.glyphs(for: modifierFlags) + KeyCodeNames.string(for: keyCode)
    }

    /// The modifier glyphs (e.g. `⌃⌥⌘`) in canonical display order.
    static func glyphs(for modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }
}

/// Maps a subset of virtual key codes to their printable label. Only the keys a
/// user is likely to bind need an explicit name; everything else falls back to
/// the system key-layout translation.
enum KeyCodeNames {
    static func string(for keyCode: UInt32) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }
        if let translated = TISKeyTranslator.character(for: keyCode) { return translated.uppercased() }
        return "Key\(keyCode)"
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12"
    ]
}

/// Translates a virtual key code into the character it produces under the
/// current keyboard layout, used purely for display.
enum TISKeyTranslator {
    static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let ptr = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return errSecParam
            }
            return UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
