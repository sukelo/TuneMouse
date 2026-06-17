import AppKit

/// frontmost 앱 bundle id를 캐싱한다. 이벤트 콜백 핫패스에서 `NSWorkspace.frontmostApplication`
/// 을 매번 조회하면 비싸므로, 앱 전환 알림으로만 갱신한다.
///
/// 갱신은 메인 스레드(워크스페이스 알림), 읽기는 콜백(메인 런루프) — 단일 스레드 접근.
final class AppContextProvider: NSObject {
    private(set) var currentBundleID: String?

    override init() {
        super.init()
        currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        currentBundleID = app?.bundleIdentifier ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
