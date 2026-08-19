import CoreGraphics

/// 변환기에 전달되는 컨텍스트(확장형). 앱별 오버라이드(축3)의 토대.
/// `targetBundleID`는 이 이벤트의 오버라이드 대상 앱 — 스크롤은 **커서 아래 앱**,
/// 버튼은 **포커스 앱**으로 파이프라인이 채운다(Phase 7).
///
/// **지연 해석**: 커서-앱 조회는 WindowServer 동기 IPC라 비싸다. 앱별 오버라이드가 하나도
/// 없으면 아무도 이 값을 읽지 않으므로 조회 자체가 일어나지 않는다
/// (`ScrollSettings.resolved(for:)` / `ButtonMappings.resolved(for:)`가 빈 perApp을 단락 평가).
/// 이벤트 1건 처리 동안만 살아 있고 메인 런루프 단일 스레드에서만 쓰인다.
final class ProcessingContext {
    private let resolve: () -> String?
    /// 이중 옵셔널 — 바깥 nil = "아직 해석 안 함", 안쪽 nil = "대상 앱 못 찾음"으로 해석된 값.
    private var cached: String??

    init(resolve: @escaping () -> String?) {
        self.resolve = resolve
    }

    var targetBundleID: String? {
        if let cached { return cached }
        let value = resolve()
        cached = .some(value)
        return value
    }
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
            Log.tap.debug("scroll line(dy=\(dy) dx=\(dx)) pointY=\(py) fixedY=\(fy, format: .fixed(precision: 2)) cont=\(continuous) app=\(context.targetBundleID ?? "?", privacy: .public)")
        case .otherMouseDown, .leftMouseDown, .rightMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            Log.tap.debug("buttonDown #\(button) (type=\(type.rawValue))")
        default:
            break
        }
        return .passUnchanged
    }
}
