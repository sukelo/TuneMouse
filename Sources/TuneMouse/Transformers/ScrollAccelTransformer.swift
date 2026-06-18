import CoreGraphics

/// 스크롤 가속 제거(균일 스크롤). macOS는 휠 입력 속도에 가속을 걸어 노치당 거리가 들쭉날쭉하다.
/// 균일 모드는 **노치당 정확한 픽셀 거리**가 목적.
///
/// 핵심: 비연속(휠) 이벤트는 앱이 **라인 delta**를 honor하고 픽셀 delta는 무시하는 경우가 많다.
/// 그래서 픽셀 필드만 덮어쓰면 "한칸당 이동거리"가 안 먹고, 속도(라인 배율)와도 합쳐지지 않는다
/// (둘 중 하나만 적용되는 증상). 이를 없애기 위해 균일 모드는 **연속(정밀) 픽셀 이벤트로 합성**한다
/// — 부드러운 스크롤과 같은 방식이라 모든 앱에서 거리가 일관된다. 속도(speedMultiplier)도 여기서 함께 반영.
///
/// 체인 순서: 방향 반전 → (여기) 균일화 → 속도 → 부드러움.
/// - 부드러운 스크롤 ON: 그쪽이 연속 픽셀로 합성하므로, 여기선 **라인만 ±1 정규화**하고 통과(속도는 하류에서 라인 배율로 반영).
/// - 부드러운 스크롤 OFF: 여기서 **연속 픽셀 이벤트를 즉시 합성**하고 원본을 소비(속도까지 반영).
final class ScrollAccelTransformer: EventTransformer {
    var settings = ScrollSettings()

    private let source = CGEventSource(stateID: .combinedSessionState)

    var isEnabled: Bool {
        settings.global.linearScroll
            || settings.perApp.values.contains { $0.linearScroll }
    }

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        guard type == .scrollWheel else { return .passUnchanged }
        let config = settings.resolved(forBundleID: context.targetBundleID)
        guard !config.passthrough, config.linearScroll else { return .passUnchanged }

        if config.smoothEnabled {
            // 부드러운 스크롤이 라인 delta를 보고 합성 → 여기선 ±1 정규화만(노치당 균일 보장).
            normalizeLine(event, axis: .vertical)
            normalizeLine(event, axis: .horizontal)
            return .passUnchanged
        }

        // 정밀 픽셀 이벤트로 합성: 노치당 (pixelsPerNotch × 속도) px. 모든 앱에서 일관.
        let pixelV = pixels(event, axis: .vertical, config: config)
        let pixelH = pixels(event, axis: .horizontal, config: config)
        guard pixelV != 0 || pixelH != 0 else { return .passUnchanged }
        postContinuous(pixelV: pixelV, pixelH: pixelH)
        return .discard
    }

    private enum Axis { case vertical, horizontal }

    private func lineField(_ axis: Axis) -> CGEventField {
        axis == .vertical ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
    }

    /// 라인 delta를 노치당 ±1로 정규화(가속된 라인 카운트 무력화). 부드러운 스크롤 경로용.
    private func normalizeLine(_ event: CGEvent, axis: Axis) {
        let field = lineField(axis)
        let value = event.getIntegerValueField(field)
        guard value != 0 else { return }
        event.setIntegerValueField(field, value: value > 0 ? 1 : -1)
    }

    /// 이 축의 합성 픽셀 거리 = 노치 부호 × pixelsPerNotch × 속도. 라인 delta가 0이면 0.
    private func pixels(_ event: CGEvent, axis: Axis, config: ScrollConfig) -> Int32 {
        let value = event.getIntegerValueField(lineField(axis))
        guard value != 0 else { return 0 }
        let notch = value > 0 ? 1.0 : -1.0
        let px = notch * config.pixelsPerNotch * config.speedMultiplier
        return Int32(px.rounded())
    }

    /// 연속(정밀) 픽셀 스크롤 이벤트 합성·post. IsContinuous=1 → 탭에서 우회(재처리 없음).
    private func postContinuous(pixelV: Int32, pixelH: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: pixelV,
            wheel2: pixelH,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.post(tap: .cgSessionEventTap)
    }
}
