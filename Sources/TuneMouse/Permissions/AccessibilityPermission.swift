import AppKit
import ApplicationServices

/// 접근성(Accessibility) 권한 확인/요청 유틸.
/// 이벤트 탭(Phase 1+)은 이 권한이 있어야 동작한다.
enum AccessibilityPermission {
    /// 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 딥링크
    private static let settingsURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    /// 권한 허용 여부 (프롬프트 없음)
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 시스템 권한 프롬프트를 띄우며 확인. 이미 허용 시 true.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        // 키 문자열 상수. SDK 심볼(kAXTrustedCheckOptionPrompt) 대신 안정적인 리터럴 사용.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 시스템 설정의 손쉬운 사용 항목을 연다.
    static func openSystemSettings() {
        if let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
