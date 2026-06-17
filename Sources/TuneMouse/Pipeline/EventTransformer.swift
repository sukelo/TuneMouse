import CoreGraphics

/// 변환기에 전달되는 컨텍스트(확장형). 앱별 오버라이드(축3)의 토대.
/// Phase 2의 스크롤 변환기는 아직 사용하지 않음 — 시그니처 seam만 깔아둔다.
struct ProcessingContext {
    let frontmostBundleID: String?
}

/// 파이프라인에 끼우는 변환기. 각 변환기는 on/off + 파라미터를 가진다.
/// 보통 이벤트를 in-place 수정하고 `.passUnchanged` 반환. 새 이벤트 생성 시 `.transformed`.
protocol EventTransformer: AnyObject {
    var isEnabled: Bool { get }
    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult
}

/// 디버그용 — 휠/버튼 이벤트를 로그로 남기고 통과. `debugEventLogging` 플래그로 파이프라인 앞에 끼움.
final class DebugLoggingTransformer: EventTransformer {
    var isEnabled: Bool { true }

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        switch type {
        case .scrollWheel:
            let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let py = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let fy = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            Log.tap.debug("scroll line(dy=\(dy) dx=\(dx)) pointY=\(py) fixedY=\(fy, format: .fixed(precision: 2)) cont=\(continuous) app=\(context.frontmostBundleID ?? "?", privacy: .public)")
        case .otherMouseDown, .leftMouseDown, .rightMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            Log.tap.debug("buttonDown #\(button) (type=\(type.rawValue))")
        default:
            break
        }
        return .passUnchanged
    }
}
