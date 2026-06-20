import Foundation

/// Downloads an update DMG and installs it in place.
///
/// Because the app is distributed ad-hoc (no Developer ID / Sparkle), the swap
/// is performed by a small detached shell helper that waits for this process to
/// quit, mounts the DMG, replaces the bundle, and relaunches. When the app is
/// not running from a writable `.app` (e.g. `swift run`), installation is not
/// possible and the caller is expected to fall back to revealing the DMG.
struct UpdateInstaller {
    enum InstallError: LocalizedError {
        case downloadFailed
        case notInstallable

        var errorDescription: String? {
            switch self {
            case .downloadFailed: return "アップデートのダウンロードに失敗しました。"
            case .notInstallable: return "このアプリは自動インストールできない場所で実行されています。"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Whether the running app can be replaced in place (a writable `.app` bundle).
    static var canInstallInPlace: Bool {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return false }
        return FileManager.default.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
    }

    /// Downloads the DMG to a temporary file and returns its local URL.
    func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("\(AppInfo.name)/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InstallError.downloadFailed
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppInfo.name)-update.dmg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Spawns the detached installer helper. The caller must terminate the app
    /// immediately afterwards so the helper can replace the bundle.
    func installInPlace(dmgURL: URL) throws {
        guard Self.canInstallInPlace else { throw InstallError.notInstallable }
        let bundleURL = Bundle.main.bundleURL

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppInfo.name)-install.sh")
        try Self.installerScript.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        // Dynamic paths are passed as positional arguments (never interpolated
        // into the script body) so they are quoted safely by the shell.
        process.arguments = [
            scriptURL.path,
            dmgURL.path,
            bundleURL.path,
            AppInfo.name,
            String(ProcessInfo.processInfo.processIdentifier)
        ]
        try process.run()
    }

    /// Waits for the parent app to quit, swaps the bundle from the mounted DMG,
    /// then relaunches. Receives all paths as positional arguments.
    private static let installerScript = """
    #!/bin/bash
    set -u
    DMG="$1"
    APP_DEST="$2"
    APP_NAME="$3"
    PID="$4"

    # Wait (up to ~20s) for the running app to exit before replacing it.
    for _ in $(seq 1 100); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.2
    done

    MOUNT="$(mktemp -d)"
    hdiutil attach "$DMG" -nobrowse -noverify -mountpoint "$MOUNT" || exit 1

    if [ -d "$MOUNT/$APP_NAME.app" ]; then
        rm -rf "$APP_DEST"
        ditto "$MOUNT/$APP_NAME.app" "$APP_DEST"
    fi

    hdiutil detach "$MOUNT" -quiet || true
    xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
    open "$APP_DEST"
    rm -f "$DMG"
    """
}
