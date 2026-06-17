import CoreGraphics

/// 스크롤 가속 제거(선형화). macOS는 휠이 들어오는 속도에 따라 픽셀 delta를 지수적으로 키운다.
/// linearScroll이 켜지면 OS의 가속된 픽셀 delta를 버리고, 라인 delta(노치 카운트)에
/// 고정 거리(pixelsPerNotch)를 곱해 덮어쓴다 → 굴리는 속도와 무관하게 노치당 거리 일정(윈도우 느낌).
///
/// 체인 순서: 방향 반전 → (여기) 선형화 → 속도 배율 → 부드러움.
/// 부드러운 스크롤이 켜진 경우 그쪽이 라인 delta만 보고 픽셀을 재구성하므로 이 변환은 무시되어 충돌 없음.
final class ScrollAccelTransformer: EventTransformer {
    var settings = ScrollSettings()

    var isEnabled: Bool {
        settings.global.linearScroll
            || settings.perApp.values.contains { $0.linearScroll }
    }

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        guard type == .scrollWheel else { return .passUnchanged }
        let config = settings.resolved(forBundleID: context.frontmostBundleID)
        guard !config.passthrough, config.linearScroll else { return .passUnchanged }
        linearize(event, axis: .vertical, pixelsPerNotch: config.pixelsPerNotch)
        linearize(event, axis: .horizontal, pixelsPerNotch: config.pixelsPerNotch)
        return .passUnchanged
    }

    private enum Axis { case vertical, horizontal }

    private func linearize(_ event: CGEvent, axis: Axis, pixelsPerNotch: Double) {
        let line: CGEventField = axis == .vertical ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
        let point: CGEventField = axis == .vertical ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2
        let fixed: CGEventField = axis == .vertical ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2

        // 라인 delta(노치 카운트)가 있을 때만 동작 = discrete 휠 입력.
        // 픽셀 delta만 있는 연속/모멘텀 스트림은 건드리지 않는다.
        let lineValue = event.getIntegerValueField(line)
        guard lineValue != 0 else { return }

        // 노치 카운트 × 고정 거리 → 가속 곡선 제거. 부호는 라인 delta가 보존.
        let pixels = Double(lineValue) * pixelsPerNotch
        event.setIntegerValueField(point, value: Int64(pixels.rounded()))
        event.setDoubleValueField(fixed, value: pixels)
    }
}
