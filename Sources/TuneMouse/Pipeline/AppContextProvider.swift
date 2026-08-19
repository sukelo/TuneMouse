import AppKit
import QuartzCore

/// 앱 컨텍스트 제공자.
/// - `currentBundleID`: **포커스(frontmost) 앱** — 앱 전환 알림으로만 갱신(버튼 등에 사용).
/// - `bundleID(atScreenPoint:)`: **커서 아래 창의 앱** — 스크롤은 커서 기준으로 라우팅되므로
///   스크롤 오버라이드는 이쪽을 써야 포커스와 무관하게 일관 적용된다(Phase 7).
///
/// 갱신/읽기 모두 메인(워크스페이스 알림 + 이벤트 콜백은 메인 런루프) — 단일 스레드 접근.
final class AppContextProvider: NSObject {
    private(set) var currentBundleID: String?

    /// 자기 자신 창은 hit-test에서 제외(설정창/오버레이).
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// PID → bundleID 캐시(PID는 앱 생존 동안 안정).
    private var pidBundleCache: [pid_t: String] = [:]

    /// 커서 좌표 기반 단기 캐시 — 스크롤 버스트 중 매 이벤트 창 조회를 막는다.
    /// 외부 옵셔널 = 캐시 없음, 내부 bundleID nil = "창 못 찾음"으로 해석된 값.
    private var cursorCache: (point: CGPoint, time: CFTimeInterval, bundleID: String?)?
    private static let cacheTTL: CFTimeInterval = 0.2
    private static let pointEpsilon: CGFloat = 2.0

    override init() {
        super.init()
        currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // PID는 재사용된다 — 종료된 앱의 캐시를 지우지 않으면 새 앱이 남의 오버라이드를 물려받는다.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        currentBundleID = app?.bundleIdentifier ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        pidBundleCache.removeValue(forKey: app.processIdentifier)
        cursorCache = nil // 종료된 앱을 가리키고 있었을 수 있다
    }

    /// 화면 좌표(CG 좌상단 원점) 아래 최상단 일반 창의 앱 bundle id. 없으면 nil.
    func bundleID(atScreenPoint point: CGPoint) -> String? {
        let now = CACurrentMediaTime()
        if let c = cursorCache,
           now - c.time < Self.cacheTTL,
           abs(c.point.x - point.x) < Self.pointEpsilon,
           abs(c.point.y - point.y) < Self.pointEpsilon {
            return c.bundleID
        }
        let resolved = resolveBundleID(atScreenPoint: point)
        cursorCache = (point, now, resolved)
        return resolved
    }

    /// CGWindowList를 앞→뒤로 훑어 커서 아래 최상단 일반 창(layer 0)의 owner를 찾는다.
    /// bounds/PID/layer만 읽으므로 **화면 기록 권한 불필요**(창 이름은 읽지 않음).
    private func resolveBundleID(atScreenPoint point: CGPoint) -> String? {
        guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in infos {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidNum = info[kCGWindowOwnerPID as String] as? Int else { continue }
            let pid = pid_t(pidNum)
            guard pid != ownPID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            if bounds.contains(point) {
                return bundleID(forPID: pid)
            }
        }
        return nil
    }

    private func bundleID(forPID pid: pid_t) -> String? {
        if let cached = pidBundleCache[pid] { return cached }
        guard let bid = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { return nil }
        pidBundleCache[pid] = bid
        return bid
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
