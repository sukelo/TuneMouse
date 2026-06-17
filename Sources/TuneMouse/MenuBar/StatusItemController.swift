import AppKit
import Combine

/// 메뉴바 상태 아이템 + 메뉴. 활성화 토글 / 권한 상태 / 설정 / 종료.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let scrollSettings: ScrollSettingsStore
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private var cancellables = Set<AnyCancellable>()

    // 동적으로 상태를 갱신할 메뉴 아이템 참조
    private let enableItem = NSMenuItem(title: "기능 활성화", action: nil, keyEquivalent: "")
    private let currentAppItem = NSMenuItem(title: "현재 앱: —", action: nil, keyEquivalent: "")
    private let appScrollToggleItem = NSMenuItem(title: "이 앱에서 스크롤 끄기", action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    // 메뉴가 열린 시점의 frontmost 앱(상태 메뉴는 accessory 앱을 활성화하지 않음).
    private var frontApp: (id: String, name: String)?

    init(appState: AppState,
         scrollSettings: ScrollSettingsStore,
         onOpenSettings: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.appState = appState
        self.scrollSettings = scrollSettings
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

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let header = NSMenuItem(title: "TuneMouse v\(version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        enableItem.target = self
        enableItem.action = #selector(toggleEnabled)
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // 현재 앱 빠른 조작 — 데일리 핵심(아이폰 미러링/게임 예외를 클릭 한 번으로)
        currentAppItem.isEnabled = false
        menu.addItem(currentAppItem)
        appScrollToggleItem.target = self
        appScrollToggleItem.action = #selector(toggleAppScroll)
        appScrollToggleItem.indentationLevel = 1
        menu.addItem(appScrollToggleItem)

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
        // 꺼짐 상태를 흐리게 해서 시각적으로 구분
        button.alphaValue = appState.isEnabled ? 1.0 : 0.4
        button.toolTip = desc
    }

    private func refreshDynamicItems() {
        enableItem.state = appState.isEnabled ? .on : .off

        // 현재 앱 + 앱별 스크롤 통과 상태
        if let front = frontApp {
            currentAppItem.title = "현재 앱: \(front.name)"
            appScrollToggleItem.isEnabled = true
            let resolved = scrollSettings.settings.resolved(forBundleID: front.id)
            appScrollToggleItem.state = resolved.passthrough ? .on : .off
        } else {
            currentAppItem.title = "현재 앱: —"
            appScrollToggleItem.isEnabled = false
            appScrollToggleItem.state = .off
        }

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
        frontApp = currentFrontApp()
        refreshDynamicItems()
    }

    /// 메뉴 열린 시점의 frontmost 앱(우리 앱·미식별 앱은 제외).
    private func currentFrontApp() -> (id: String, name: String)? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier, id != "com.tunemouse.TuneMouse" else { return nil }
        return (id, app.localizedName ?? id)
    }

    // MARK: - 액션

    @objc private func toggleEnabled() {
        appState.isEnabled.toggle()
    }

    /// 현재 앱의 "스크롤 통과(가공 끄기)"를 즉석 토글.
    /// 새 오버라이드는 전역값 복사 기반(Phase 6 모델). 토글 해제로 전역과 같아지면 항목 제거.
    @objc private func toggleAppScroll() {
        guard let front = frontApp else { return }
        var config = scrollSettings.settings.perApp[front.id] ?? scrollSettings.settings.global
        config.passthrough.toggle()
        if config == scrollSettings.settings.global {
            scrollSettings.settings.perApp[front.id] = nil
        } else {
            scrollSettings.settings.perApp[front.id] = config
        }
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
