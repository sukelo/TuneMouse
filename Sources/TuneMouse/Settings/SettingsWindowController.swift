import AppKit
import SwiftUI

/// 설정 창. SwiftUI 뷰를 NSWindow에 호스팅한다.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let appState: AppState
    private let scrollSettings: ScrollSettingsStore
    private let buttonMappings: ButtonMappingStore

    init(appState: AppState, scrollSettings: ScrollSettingsStore, buttonMappings: ButtonMappingStore) {
        self.appState = appState
        self.scrollSettings = scrollSettings
        self.buttonMappings = buttonMappings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(
                appState: appState,
                scrollSettings: scrollSettings,
                buttonMappings: buttonMappings
            ))
            let win = NSWindow(contentViewController: hosting)
            win.title = "TuneMouse 설정"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        // accessory 앱이라 창을 앞으로 가져오려면 앱을 활성화해야 함
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
