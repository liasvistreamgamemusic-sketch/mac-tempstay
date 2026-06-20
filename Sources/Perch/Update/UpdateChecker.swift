import Foundation

/// A newer release discovered on GitHub, ready to download and install.
struct AvailableUpdate: Sendable {
    let version: SemanticVersion
    let tagName: String
    let releaseNotes: String
    let dmgURL: URL
}

/// Queries the GitHub Releases API for the latest release and decides whether it
/// supersedes the running build. Pure networking + parsing; no UI side effects.
struct UpdateChecker {
    /// Errors surfaced when an update check cannot complete.
    enum CheckError: LocalizedError {
        case badResponse
        case noDownloadableAsset

        var errorDescription: String? {
            switch self {
            case .badResponse: return "アップデート情報の取得に失敗しました。"
            case .noDownloadableAsset: return "最新リリースにインストール可能なファイルが見つかりませんでした。"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns the available update when the latest release is newer than
    /// `currentVersion`, or `nil` when the app is already up to date.
    func checkForUpdate(currentVersion: String = AppInfo.version) async throws -> AvailableUpdate? {
        guard let url = AppInfo.latestReleaseAPIURL else { throw CheckError.badResponse }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub requires a User-Agent on every API request.
        request.setValue("\(AppInfo.name)/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CheckError.badResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let latest = SemanticVersion(release.tagName) else { throw CheckError.badResponse }

        // Already current (or newer, e.g. a local build): nothing to offer.
        guard let current = SemanticVersion(currentVersion), latest > current else { return nil }

        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
              let dmgURL = URL(string: asset.browserDownloadURL) else {
            throw CheckError.noDownloadableAsset
        }

        return AvailableUpdate(
            version: latest,
            tagName: release.tagName,
            releaseNotes: release.body ?? "",
            dmgURL: dmgURL
        )
    }
}

// MARK: - GitHub API payload

/// Subset of the GitHub "latest release" response we depend on.
private struct GitHubRelease: Decodable {
    let tagName: String
    let body: String?
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case assets
    }
}
