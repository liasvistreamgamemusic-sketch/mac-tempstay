import Foundation

/// Central place for app-wide identity constants so they are never hard-coded
/// at multiple call sites.
enum AppInfo {
    static let name = "Perch"
    static let bundleIdentifier = "dev.perch.Perch"

    /// Version string used when running outside a packaged bundle (e.g. `swift run`).
    /// Update checks treat this as "not a real release" and skip auto-prompting.
    static let developmentVersion = "0.0.0-dev"

    /// GitHub repository the auto-updater queries for new releases.
    static let repositoryOwner = "liasvistreamgamemusic-sketch"
    static let repositoryName = "mac-tempstay"

    /// GitHub REST endpoint for the latest published release.
    static var latestReleaseAPIURL: URL? {
        URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")
    }

    /// Resolved at runtime from the bundle's Info.plist; falls back to a
    /// sensible default when running outside a bundle (e.g. `swift run`).
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? developmentVersion
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Whether the app is running from a packaged `.app` bundle (vs `swift run`).
    static var isRunningFromBundle: Bool {
        version != developmentVersion
    }
}
