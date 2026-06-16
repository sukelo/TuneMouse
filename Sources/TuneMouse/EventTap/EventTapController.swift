import CoreGraphics
import Foundation

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

    init(processor: EventProcessor) {
        self.processor = processor
    }

    /// 관심 이벤트: 스크롤 + 마우스 버튼(클릭/드래그). 인프라이므로 넓게 캡처(처리는 통과).
    private static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .scrollWheel,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    }()

    /// 탭 생성 + 런루프 등록 + 활성화. 권한 없으면 false.
    @discardableResult
    func install() -> Bool {
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
    func setEnabled(_ enabled: Bool) {
        if enabled {
            install()
        } else {
            uninstall()
        }
    }

    /// 콜백 핫패스. C 트램펄린에서 호출.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 탭이 OS에 의해 비활성화되면 즉시 재활성화 (안전 설계)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = tapPort {
                CGEvent.tapEnable(tap: port, enable: true)
                Log.tap.notice("탭 비활성 감지(type=\(type.rawValue)) → 재활성화")
            }
            return Unmanaged.passUnretained(event)
        }

        // 트랙패드/연속 스크롤은 절대 건드리지 않고 통과 (변경 불가 제약)
        if type == .scrollWheel, EventClassifier.isContinuousScroll(event) {
            return Unmanaged.passUnretained(event)
        }

        switch processor.process(type: type, event: event) {
        case .passUnchanged:
            return Unmanaged.passUnretained(event)
        case .transformed(let newEvent):
            return Unmanaged.passUnretained(newEvent)
        case .discard:
            return nil
        }
    }
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
