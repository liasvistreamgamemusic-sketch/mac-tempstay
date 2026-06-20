import AppKit

/// Drives the end-to-end update experience: checks GitHub, prompts the user,
/// downloads the DMG and installs it in place (relaunching), with a guided
/// fallback to reveal the DMG when in-place install is not possible.
///
/// All UI lives here; `UpdateChecker`/`UpdateInstaller` stay side-effect free.
@MainActor
final class AppUpdater {
    private let settingsStore: SettingsStore
    private let checker = UpdateChecker()
    private let installer = UpdateInstaller()
    private var isBusy = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    /// - Parameter userInitiated: when `true` (the "Check for updates" button),
    ///   also report "up to date" and surface errors. Background launch checks
    ///   stay silent unless an update is available.
    func checkForUpdates(userInitiated: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            guard let update = try await checker.checkForUpdate() else {
                if userInitiated { presentUpToDate() }
                return
            }
            // Honour a previously skipped version on background checks only.
            if !userInitiated, settingsStore.settings.skippedUpdateVersion == update.tagName {
                return
            }
            await handleAvailable(update, userInitiated: userInitiated)
        } catch {
            if userInitiated {
                presentError(error)
            } else {
                AppLog.error("Update check failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Prompts

    private func handleAvailable(_ update: AvailableUpdate, userInitiated: Bool) async {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "新しいバージョン \(update.version) が利用可能です"
        alert.informativeText = informativeText(for: update)
        alert.addButton(withTitle: "アップデート")
        alert.addButton(withTitle: "後で")
        alert.addButton(withTitle: "このバージョンをスキップ")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            await startInstall(update)
        case .alertThirdButtonReturn:
            settingsStore.update { $0.skippedUpdateVersion = update.tagName }
        default:
            break // "後で": ask again next launch.
        }
    }

    private func informativeText(for update: AvailableUpdate) -> String {
        let header = "現在のバージョン: \(AppInfo.version)"
        let notes = update.releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return header }
        // Keep the dialog compact for long changelogs.
        let trimmed = notes.count > 600 ? String(notes.prefix(600)) + "…" : notes
        return "\(header)\n\n\(trimmed)"
    }

    // MARK: - Download + install

    private func startInstall(_ update: AvailableUpdate) async {
        let hud = UpdateProgressHUD()
        hud.show(message: "アップデートをダウンロード中…")
        defer { hud.close() }

        do {
            let dmgURL = try await installer.download(update.dmgURL)
            if UpdateInstaller.canInstallInPlace {
                try installer.installInPlace(dmgURL: dmgURL)
                NSApp.terminate(nil) // helper waits for exit, then swaps + relaunches.
            } else {
                // Guided fallback: open the DMG so the user can drag-install.
                hud.close()
                NSWorkspace.shared.open(dmgURL)
                presentManualInstallNote()
            }
        } catch {
            presentError(error)
        }
    }

    // MARK: - Result alerts

    private func presentUpToDate() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "最新バージョンを使用中です"
        alert.informativeText = "\(AppInfo.name) \(AppInfo.version) は最新です。"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentManualInstallNote() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "ダウンロードが完了しました"
        alert.informativeText = "開いた DMG から \(AppInfo.name).app を Applications フォルダにドラッグしてください。"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentError(_ error: Error) {
        AppLog.error("Update error: \(error.localizedDescription)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(AppInfo.name) — アップデート"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// A small always-on-top panel with an indeterminate spinner shown while the
/// update DMG downloads (the download API does not expose granular progress).
@MainActor
private final class UpdateProgressHUD {
    private var window: NSWindow?

    func show(message: String) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
            styleMask: [.titled, .hudWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = AppInfo.name
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimation(nil)

        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false

        let content = panel.contentView!
        content.addSubview(spinner)
        content.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            spinner.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20)
        ])

        panel.makeKeyAndOrderFront(nil)
        self.window = panel
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
