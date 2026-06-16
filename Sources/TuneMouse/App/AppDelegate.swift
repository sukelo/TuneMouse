import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var statusController: StatusItemController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("앱 시작 (accessory 정책)")
        statusController = StatusItemController(
            appState: appState,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        appState.refreshAccessibility()
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(appState: appState)
        }
        settingsWindow?.show()
    }
}
