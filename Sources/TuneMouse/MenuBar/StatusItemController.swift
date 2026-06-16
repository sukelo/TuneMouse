import AppKit
import Combine

/// 메뉴바 상태 아이템 + 메뉴. 활성화 토글 / 권한 상태 / 설정 / 종료.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private var cancellables = Set<AnyCancellable>()

    // 동적으로 상태를 갱신할 메뉴 아이템 참조
    private let enableItem = NSMenuItem(title: "기능 활성화", action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(appState: AppState,
         onOpenSettings: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.appState = appState
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        buildMenu()
        updateIcon()

        // 활성화 상태가 바뀌면 아이콘 갱신
        appState.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    // MARK: - 구성

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "TuneMouse", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        enableItem.target = self
        enableItem.action = #selector(toggleEnabled)
        menu.addItem(enableItem)

        menu.addItem(.separator())

        permissionItem.target = self
        permissionItem.action = #selector(handlePermission)
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "TuneMouse 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = appState.isEnabled ? "computermouse.fill" : "computermouse"
        let desc = appState.isEnabled ? "TuneMouse (켜짐)" : "TuneMouse (꺼짐)"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: desc)
        button.image?.isTemplate = true
    }

    private func refreshDynamicItems() {
        enableItem.state = appState.isEnabled ? .on : .off

        if appState.hasAccessibility {
            permissionItem.title = "접근성 권한: 허용됨"
            permissionItem.isEnabled = false
        } else {
            permissionItem.title = "접근성 권한 필요 — 열기"
            permissionItem.isEnabled = true
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        appState.refreshAccessibility()
        refreshDynamicItems()
    }

    // MARK: - 액션

    @objc private func toggleEnabled() {
        appState.isEnabled.toggle()
    }

    @objc private func handlePermission() {
        AccessibilityPermission.promptIfNeeded()
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
