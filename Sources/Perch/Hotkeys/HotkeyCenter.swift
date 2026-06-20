import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys via the Carbon `RegisterEventHotKey` API.
///
/// This is the standard way to obtain global shortcuts without requiring the
/// Accessibility permission. Hotkey events are delivered on the main run loop,
/// so handlers run on the main thread.
final class HotkeyCenter {
    typealias Handler = () -> Void

    private struct Registration {
        let ref: EventHotKeyRef
        let handler: Handler
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private let signature: OSType = 0x5052_4348 // 'PRCH'

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    /// Registers `combo`, returning `true` on success. Invalid combos (no
    /// modifier) are rejected up front.
    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping Handler) -> Bool {
        guard combo.isValid else { return false }

        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            carbonModifiers(from: combo.modifierFlags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            AppLog.error("Failed to register hotkey \(combo.displayString) (status \(status))")
            return false
        }

        registrations[id] = Registration(ref: ref, handler: handler)
        return true
    }

    /// Removes every registered hotkey. Call before re-registering on settings
    /// changes to avoid duplicates/leaks.
    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
    }

    // MARK: - Event handling

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                return center.handle(event: event)
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == signature,
              let registration = registrations[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }

        registration.handler()
        return noErr
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}
