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
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    /// 접근성 권한 허용 여부 (읽기 전용, refreshAccessibility로 갱신)
    @Published private(set) var hasAccessibility: Bool = false

    init() {
        // 기본값: 활성화 = true (최초 실행 시)
        if UserDefaults.standard.object(forKey: Keys.isEnabled) == nil {
            UserDefaults.standard.set(true, forKey: Keys.isEnabled)
        }
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        hasAccessibility = AccessibilityPermission.isTrusted()
    }

    func refreshAccessibility() {
        let trusted = AccessibilityPermission.isTrusted()
        if trusted != hasAccessibility {
            hasAccessibility = trusted
        }
    }
}
