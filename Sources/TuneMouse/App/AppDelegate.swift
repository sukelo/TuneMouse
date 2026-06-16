import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var statusController: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    // 처리기 선택: UserDefaults "debugEventLogging" 가 true면 이벤트를 로그로 출력(검증용), 아니면 통과.
    private let tapController: EventTapController = {
        let debug = UserDefaults.standard.bool(forKey: "debugEventLogging")
        let processor: EventProcessor = debug ? DebugLoggingProcessor() : PassthroughProcessor()
        Log.tap.notice("처리기: \(debug ? "DebugLogging" : "Passthrough", privacy: .public)")
        return EventTapController(processor: processor)
    }()
    private var panicHotKey: PanicHotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("앱 시작 (accessory 정책)")
        statusController = StatusItemController(
            appState: appState,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        appState.refreshAccessibility()

        // 권한이 없으면 시작 시 한 번 시스템 프롬프트로 요청 — 손쉬운 사용 목록에 앱이 등록된다.
        if !appState.hasAccessibility {
            AccessibilityPermission.promptIfNeeded()
            Log.permission.notice("접근성 권한 미허용 — 시작 시 권한 요청")
        }

        // 탭은 (기능 활성화 && 접근성 권한)일 때만 설치한다.
        Publishers.CombineLatest(appState.$isEnabled, appState.$hasAccessibility)
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled, hasAccessibility in
                Log.tap.notice("상태 갱신: enabled=\(enabled, privacy: .public) hasAX=\(hasAccessibility, privacy: .public)")
                self?.tapController.setEnabled(enabled && hasAccessibility)
            }
            .store(in: &cancellables)

        // 패닉 키: 전역 단축키로 기능 즉시 on/off
        let hotKey = PanicHotKey(onTrigger: { [weak self] in
            self?.appState.isEnabled.toggle()
        })
        hotKey.register()
        panicHotKey = hotKey
    }

    func applicationWillTerminate(_ notification: Notification) {
        panicHotKey?.unregister()
        tapController.uninstall()
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(appState: appState)
        }
        settingsWindow?.show()
    }
}
