import Foundation
import OSLog

/// Thin wrapper over `os.Logger` so the whole app logs through one channel and
/// we never leave stray `print()` calls behind.
enum AppLog {
    private static let logger = Logger(subsystem: AppInfo.bundleIdentifier, category: "app")

    static func debug(_ message: String) { logger.debug("\(message, privacy: .public)") }
    static func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    static func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
