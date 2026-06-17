import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let scrollSettings = ScrollSettingsStore()
    private let buttonMappings = ButtonMappingStore()
    private var statusController: StatusItemController?
    private var settingsWindow: SettingsWindowController?

    // 파이프라인 구성요소
    private let contextProvider = AppContextProvider()
    private let buttonRemap = ButtonRemapTransformer()
    private let scrollDirection = ScrollDirectionTransformer()
    private let scrollAccel = ScrollAccelTransformer()
    private let scrollSpeed = ScrollSpeedTransformer()
    private let smoothAnimator = SmoothScrollAnimator()
    private lazy var smoothScroll = SmoothScrollTransformer(animator: smoothAnimator)
    private lazy var tapController: EventTapController = {
        let debug = UserDefaults.standard.bool(forKey: "debugEventLogging")
        var transformers: [EventTransformer] = [buttonRemap, scrollDirection, scrollAccel, scrollSpeed, smoothScroll]
        if debug { transformers.append(DebugLoggingTransformer()) } // 맨 뒤 → 변환 후 최종값 로그
        Log.tap.notice("파이프라인 변환기 \(transformers.count)개 (debug=\(debug, privacy: .public))")
        let pipeline = EventPipeline(transformers: transformers, contextProvider: contextProvider)
        return EventTapController(processor: pipeline)
    }()

    private var panicHotKey: PanicHotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("앱 시작 (accessory 정책)")
        statusController = StatusItemController(
            appState: appState,
            scrollSettings: scrollSettings,
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
        // DispatchQueue.main: 메뉴 트래킹 등 비기본 런루프 모드에서도 지연 없이 전달.
        Publishers.CombineLatest(appState.$isEnabled, appState.$hasAccessibility)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled, hasAccessibility in
                Log.tap.notice("상태 갱신: enabled=\(enabled, privacy: .public) hasAX=\(hasAccessibility, privacy: .public)")
                let active = enabled && hasAccessibility
                if !active { self?.buttonRemap.reset() } // 끌 때 소비 상태 초기화(스턱/잔류 방지)
                self?.tapController.setEnabled(active)
            }
            .store(in: &cancellables)

        // 패닉 키: 전역 단축키로 기능 즉시 on/off
        let hotKey = PanicHotKey(onTrigger: { [weak self] in
            self?.appState.isEnabled.toggle()
        })
        hotKey.register()
        panicHotKey = hotKey

        // 워치독(3초): 런타임 권한 변화 반영(F2) + 탭이 죽었으면 재활성화(F4)
        Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.watchdogTick() }
            .store(in: &cancellables)

        // 스크롤 설정 → 변환기 파라미터 라이브 반영
        scrollSettings.$settings
            .sink { [weak self] settings in self?.applyScrollSettings(settings) }
            .store(in: &cancellables)

        // 버튼 매핑 → 변환기 라이브 반영
        buttonMappings.$mappings
            .sink { [weak self] mappings in self?.buttonRemap.mappings = mappings }
            .store(in: &cancellables)
    }

    private func applyScrollSettings(_ settings: ScrollSettings) {
        // 모든 스크롤 변환기가 앱별 해석을 하도록 전체 설정 전달
        scrollDirection.settings = settings
        scrollAccel.settings = settings
        scrollSpeed.settings = settings
        smoothScroll.settings = settings
    }

    /// 주기적 건강 점검. refreshAccessibility가 권한 변화를 @Published로 알리면
    /// 위 CombineLatest가 설치/해제를 처리한다. 탭이 켜져 있어야 하는데 죽었으면 복구.
    private func watchdogTick() {
        appState.refreshAccessibility()
        if appState.isEnabled && appState.hasAccessibility {
            tapController.ensureEnabledIfInstalled()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panicHotKey?.unregister()
        tapController.uninstall()
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                appState: appState,
                scrollSettings: scrollSettings,
                buttonMappings: buttonMappings
            )
        }
        settingsWindow?.show()
    }
}
