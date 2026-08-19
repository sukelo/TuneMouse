import AppKit
import Combine

/// 앱 전역 상태. 현재는 활성화 토글 + 접근성 권한 상태만.
/// 추후 스크롤/버튼/앱별 오버라이드 설정이 이 계층(또는 별도 SettingsStore)으로 확장된다.
@MainActor
final class AppState: ObservableObject {
    private enum Keys {
        static let isEnabled = "isEnabled"
    }

    /// 전체 기능 on/off. 패닉 키/메뉴바 토글이 이 값을 건드린다. (지금은 상태만, 기능 연결은 Phase 1+)
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
            Log.menu.notice("기능 활성화 토글: \(self.isEnabled, privacy: .public)")
        }
    }

    /// 접근성 권한 허용 여부 (읽기 전용, refreshAccessibility로 갱신)
    @Published private(set) var hasAccessibility: Bool = false

    /// 이벤트 탭이 **실제로** 설치돼 동작 중인지. `isEnabled`는 사용자의 의사일 뿐이고,
    /// 권한/설치 실패/과부하 포기로 실제 동작하지 않을 수 있다 — 메뉴바 표시는 이 값을 따른다.
    @Published private(set) var isTapActive: Bool = false

    /// 패닉 키가 실제로 등록됐는지. 실패했으면 UI가 그 조합을 광고하면 안 된다.
    @Published private(set) var panicHotKeyRegistered: Bool = false

    /// 설정창에서 마우스 버튼을 녹화하는 중. true인 동안 버튼 리매핑이 이벤트를 소비하지 않아
    /// 이미 매핑된 버튼도 다시 지정할 수 있다.
    @Published var isCapturingButton: Bool = false

    /// 로그인 시 자동 시작 여부. 진실 소스는 SMAppService — setLaunchAtLogin으로만 변경.
    @Published private(set) var launchAtLogin: Bool = false

    init() {
        // 기본값: 활성화 = true (최초 실행 시)
        if UserDefaults.standard.object(forKey: Keys.isEnabled) == nil {
            UserDefaults.standard.set(true, forKey: Keys.isEnabled)
        }
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        hasAccessibility = AccessibilityPermission.isTrusted()
        launchAtLogin = LoginItemManager.isEnabled
    }

    func setPanicHotKeyRegistered(_ registered: Bool) {
        panicHotKeyRegistered = registered
    }

    func setTapActive(_ active: Bool) {
        if active != isTapActive {
            isTapActive = active
            Log.tap.notice("탭 실동작 상태: \(active, privacy: .public)")
        }
    }

    func refreshAccessibility() {
        let trusted = AccessibilityPermission.isTrusted()
        if trusted != hasAccessibility {
            hasAccessibility = trusted
            Log.permission.notice("접근성 권한 상태 변경: \(trusted, privacy: .public)")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItemManager.setEnabled(enabled)
        launchAtLogin = LoginItemManager.isEnabled // 실제 상태 반영
    }

    func refreshLaunchAtLogin() {
        let actual = LoginItemManager.isEnabled
        if actual != launchAtLogin {
            launchAtLogin = actual
        }
    }
}
