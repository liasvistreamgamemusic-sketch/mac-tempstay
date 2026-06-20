import Foundation

/// A minimal semantic version (`major.minor.patch`) used to decide whether a
/// GitHub release is newer than the running build. Tolerant of a leading `v`
/// and of pre-release/build metadata, which it discards for comparison.
struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses strings such as `"1.2.3"`, `"v1.2"`, or `"1.2.3-beta.1"`. Returns
    /// `nil` when the leading component is not a number.
    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = text.first, first == "v" || first == "V" { text.removeFirst() }
        // Discard pre-release (`-`) and build (`+`) metadata.
        if let dash = text.firstIndex(of: "-") { text = String(text[..<dash]) }
        if let plus = text.firstIndex(of: "+") { text = String(text[..<plus]) }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard let first = parts.first, let major = Int(first) else { return nil }
        // Missing minor/patch default to 0; a malformed component fails the parse.
        guard let minor = parts.count > 1 ? Int(parts[1]) : 0,
              let patch = parts.count > 2 ? Int(parts[2]) : 0 else { return nil }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
