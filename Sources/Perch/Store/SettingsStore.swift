import Combine
import Foundation

/// Observable, persistent home for `AppSettings`.
///
/// Reads/writes a single JSON blob in `UserDefaults`. Publishes changes so the
/// SwiftUI settings window and the hotkey/login subsystems can react. The store
/// is the single source of truth — nothing else caches settings.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey = "AppSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.load(from: defaults, key: storageKey) ?? .default
    }

    /// Convenience mutator that keeps call sites declarative.
    func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
    }

    func shortcut(for action: HotkeyAction) -> KeyCombo {
        settings.shortcut(for: action)
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: storageKey)
        } catch {
            AppLog.error("Failed to persist settings: \(error.localizedDescription)")
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            AppLog.error("Failed to decode settings, falling back to defaults: \(error.localizedDescription)")
            return nil
        }
    }
}
