import AppKit

// Entry point. A status-bar agent (LSUIElement), so there is no main menu or
// Dock presence; the AppDelegate builds everything once the app launches.
// Top-level executable code runs on the main thread, so we assume main-actor
// isolation to construct the (main-actor) delegate and start the run loop.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
