import CoreGraphics

/// 이벤트 처리 결과. 세 축(스크롤/액션/오버라이드)이 이 타입을 통해 결과를 돌려준다.
enum ProcessResult {
    case passUnchanged          // 원본 통과. **in-place 수정(필드 변경)도 이 케이스 사용** — 동일 객체라 소유권 이동 없음
    case transformed(CGEvent)   // 새로 생성한 이벤트로 교체 (시스템이 소유권을 가져감 → passRetained 처리됨)
    case discard                // 이벤트 소비(재전송 안 함)
}

/// 처리 파이프라인의 seam. Phase 2+에서 스크롤 변환기·액션 매핑·앱별 오버라이드가
/// 이 프로토콜 구현으로 끼워진다. Phase 1은 통과/디버그 구현체만.
protocol EventProcessor: AnyObject {
    func process(type: CGEventType, event: CGEvent) -> ProcessResult
}

/// 항등 처리기 — 아무것도 바꾸지 않고 통과. Phase 1 기본값.
final class PassthroughProcessor: EventProcessor {
    func process(type: CGEventType, event: CGEvent) -> ProcessResult {
        .passUnchanged
    }
}

/// 디버그용 — 휠/버튼 이벤트를 로그로만 남기고 통과. 탭 동작 검증용(기본 off).
final class DebugLoggingProcessor: EventProcessor {
    func process(type: CGEventType, event: CGEvent) -> ProcessResult {
        switch type {
        case .scrollWheel:
            let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            Log.tap.debug("scroll dy=\(dy) dx=\(dx) continuous=\(continuous)")
        case .otherMouseDown, .leftMouseDown, .rightMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            Log.tap.debug("buttonDown #\(button) (type=\(type.rawValue))")
        default:
            break
        }
        return .passUnchanged
    }
}
