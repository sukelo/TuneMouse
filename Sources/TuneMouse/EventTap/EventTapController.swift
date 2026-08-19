import CoreGraphics
import Foundation
import QuartzCore

/// 전역 마우스 이벤트 탭의 생성/생명주기/재활성화를 담당.
/// Phase 1은 메인 런루프에 콜백을 등록(통과 단계라 충분히 빠름). 후속 단계에서 부하 시 전용 스레드로 이전.
///
/// 동시성: 콜백은 메인 런루프에서 실행되고, install/uninstall도 메인(AppDelegate)에서 호출 →
/// 사실상 메인 스레드 단일 접근. (전용 스레드 이전 시 상태 접근 재검토 필요.)
final class EventTapController {
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let processor: EventProcessor
    private(set) var isInstalled = false

    /// 과부하로 스스로 포기한 상태. true인 동안 install()은 거부된다(워치독 재설치 루프 방지).
    /// 사용자가 기능을 다시 켜면(setEnabled(true)) 해제된다.
    private(set) var isDisabledByOverload = false

    /// 과부하로 탭을 포기했을 때 알림(메뉴바 표시 등).
    var onOverload: (() -> Void)?

    /// 최근 타임아웃 시각들 — 짧은 시간에 반복되면 재활성화를 포기한다.
    private var recentTimeouts: [CFTimeInterval] = []
    private static let timeoutWindow: CFTimeInterval = 10.0
    private static let maxTimeoutsInWindow = 5

    init(processor: EventProcessor) {
        self.processor = processor
    }

    /// 관심 이벤트: 스크롤 + **추가 버튼(2번 이상)** 만.
    /// 좌/우 클릭과 그 드래그는 매핑 대상이 아니므로(ButtonRemapTransformer가 button >= 2만 처리)
    /// 아예 캡처하지 않는다 — 드래그 중 핫패스 부하를 없애고, 좌클릭이 소비될 여지를 원천 차단.
    private static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .scrollWheel,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged
        ]
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    }()

    /// 탭 생성 + 런루프 등록 + 활성화. 권한 없으면 false.
    @discardableResult
    func install() -> Bool {
        guard !isDisabledByOverload else { return false }
        guard tapPort == nil else { return true }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            Log.tap.error("CGEvent.tapCreate 실패 — 접근성 권한 미허용 가능성")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        tapPort = port
        runLoopSource = source
        isInstalled = true
        Log.tap.notice("이벤트 탭 설치됨")
        return true
    }

    /// 탭 비활성화 + 런루프에서 제거 + 무효화.
    func uninstall() {
        guard let port = tapPort else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(port)
        tapPort = nil
        runLoopSource = nil
        isInstalled = false
        Log.tap.notice("이벤트 탭 해제됨")
    }

    /// 활성/비활성. 끌 때는 완전 해제(오버헤드 0, 콜백 미호출).
    /// 켜는 것은 사용자의 명시적 의사이므로 과부하 포기 상태를 해제하고 재시도한다.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            isDisabledByOverload = false
            recentTimeouts.removeAll()
            return install()
        } else {
            uninstall()
            return true
        }
    }

    /// 설치돼 있는데 OS가 탭을 비활성화했으면 재활성화 (워치독 안전망).
    /// 콜백의 tapDisabled 신호를 놓치는 드문 경우 대비.
    func ensureEnabledIfInstalled() {
        guard let tapPort, !CGEvent.tapIsEnabled(tap: tapPort) else { return }
        CGEvent.tapEnable(tap: tapPort, enable: true)
        Log.tap.notice("워치독: 탭 비활성 감지 → 재활성화")
    }

    /// 콜백 핫패스. C 트램펄린에서 호출.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 탭이 OS에 의해 비활성화되면 재활성화 (안전 설계).
        // 단, 무조건 즉시 재활성화하면 콜백이 느릴 때 "멈춤 → 해제 → 재설치 → 멈춤"이 반복되어
        // 사용자에게는 시스템 전체 마우스가 얼어붙은 것으로 보인다. 반복되면 포기하고 알린다.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let now = CACurrentMediaTime()
            recentTimeouts.removeAll { now - $0 > Self.timeoutWindow }
            recentTimeouts.append(now)

            if recentTimeouts.count >= Self.maxTimeoutsInWindow {
                Log.tap.error("탭 비활성 \(self.recentTimeouts.count)회 반복 — 재활성화 포기(과부하). 기능을 다시 켜면 재시도.")
                recentTimeouts.removeAll()
                isDisabledByOverload = true
                uninstall()
                onOverload?()
                return Unmanaged.passUnretained(event)
            }

            if let port = tapPort {
                CGEvent.tapEnable(tap: port, enable: true)
                Log.tap.notice("탭 비활성 감지(type=\(type.rawValue)) → 재활성화")
            }
            return Unmanaged.passUnretained(event)
        }

        // 우리가 합성한 이벤트는 무조건 통과 — 재진입/무한 재귀 방지의 1차 방어선.
        if SynthesizedEvent.isOurs(event) {
            Log.tap.debug("합성 이벤트 마커 감지 → 통과(재진입 차단)")
            return Unmanaged.passUnretained(event)
        }

        // 트랙패드/연속 스크롤은 절대 건드리지 않고 통과 (변경 불가 제약)
        if type == .scrollWheel, EventClassifier.isContinuousScroll(event) {
            return Unmanaged.passUnretained(event)
        }

        switch processor.process(type: type, event: event) {
        case .passUnchanged:
            // 원본(또는 in-place 수정된 동일 객체) 통과 — 시스템이 이미 소유
            return Unmanaged.passUnretained(event)
        case .transformed(let newEvent):
            // 새로 생성한 이벤트는 소유권을 시스템에 넘김 → passRetained (+1)
            return Unmanaged.passRetained(newEvent)
        case .discard:
            return nil
        }
    }

    /// 콜백에 넘긴 refcon은 unretained — 설치된 채로 해제되면 C 콜백에서 use-after-free가 된다.
    deinit { uninstall() }
}

/// C 콜백 트램펄린. `@convention(c)` 호환을 위해 컨텍스트를 캡처하지 않고,
/// refcon으로 받은 포인터에서 컨트롤러를 복원해 위임한다.
private func eventTapCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(refcon).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}
