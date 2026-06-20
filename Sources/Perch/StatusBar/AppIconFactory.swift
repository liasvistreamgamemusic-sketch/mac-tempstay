import AppKit

/// Provides the status bar (menu bar) icon. Uses an SF Symbol rendered as a
/// template image so it adapts to light/dark menu bars automatically.
enum AppIconFactory {
    /// The menu bar glyph. `tray.full.fill` reflects the app's purpose — a
    /// shelf that temporarily holds items you are dragging around.
    static func statusBarImage(itemCount: Int = 0) -> NSImage? {
        let symbolName = itemCount > 0 ? "tray.full.fill" : "tray"
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppInfo.name)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
