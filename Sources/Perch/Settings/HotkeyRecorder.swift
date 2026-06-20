import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A SwiftUI control for recording a global shortcut. Click to arm, then press
/// the desired combination; Esc cancels, Delete clears to the default. Only
/// combos carrying ⌘ or ⌃ are accepted (see `KeyCombo.isValid`).
struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var combo: KeyCombo
    /// Called with the newly recorded combo (already validated).
    var onChange: (KeyCombo) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = { newCombo in
            combo = newCombo
            onChange(newCombo)
        }
        button.combo = combo
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.combo = combo
    }
}

/// AppKit button that records a key combination while armed.
final class RecorderButton: NSButton {
    var onRecord: ((KeyCombo) -> Void)?
    var combo: KeyCombo = KeyCombo(keyCode: 0, modifierFlags: []) {
        didSet { updateTitle() }
    }

    private var isRecording = false {
        didSet { updateTitle(); updateAppearance() }
    }
    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { removeMonitor() }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopRecording() {
        isRecording = false
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// Returns `true` when the event was consumed by recording.
    private func handle(_ event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else { return false }

        // Esc cancels without changing the binding.
        if event.keyCode == kVK_Escape {
            stopRecording()
            return true
        }

        let candidate = KeyCombo(
            keyCode: UInt32(event.keyCode),
            modifierFlags: event.modifierFlags
        )
        // Reject combos without a ⌘/⌃ anchor — let the user try again.
        guard candidate.isValid else {
            NSSound.beep()
            return true
        }

        combo = candidate
        onRecord?(candidate)
        stopRecording()
        return true
    }

    private func updateTitle() {
        if isRecording {
            title = "キーを入力…"
        } else {
            title = combo.displayString.isEmpty ? "未設定" : combo.displayString
        }
    }

    private func updateAppearance() {
        contentTintColor = isRecording ? .controlAccentColor : nil
    }
}
