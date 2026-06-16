import ServiceManagement

/// 로그인 시 자동 시작 관리. SMAppService.mainApp(macOS 13+) 사용.
/// 진실 소스는 항상 `SMAppService.mainApp.status` — UserDefaults에 따로 저장하지 않는다.
@MainActor
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 등록/해제. 실패해도 throw하지 않고 로그만 남긴다(설정 토글은 실제 상태로 되돌아감).
    static func setEnabled(_ enabled: Bool) {
        do {
            switch (enabled, SMAppService.mainApp.status) {
            case (true, let s) where s != .enabled:
                try SMAppService.mainApp.register()
                Log.app.notice("로그인 항목 등록")
            case (false, .enabled):
                try SMAppService.mainApp.unregister()
                Log.app.notice("로그인 항목 해제")
            default:
                break // 이미 원하는 상태
            }
        } catch {
            Log.app.error("로그인 항목 변경 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
