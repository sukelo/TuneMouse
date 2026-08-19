import CoreGraphics

/// 스크롤 방향 반전. 세로(axis1)/가로(axis2) 각각 토글. 앱별 설정 해석(통과 시 skip).
/// line/point/fixedPt 세 delta 필드를 함께 부호 반전(일부만 바꾸면 앱별 회귀).
final class ScrollDirectionTransformer: EventTransformer {
    var settings = ScrollSettings()

    var isEnabled: Bool {
        settings.global.invertVertical || settings.global.invertHorizontal
            || settings.perApp.values.contains { $0.invertVertical || $0.invertHorizontal }
    }

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        guard type == .scrollWheel else { return .passUnchanged }
        let config = settings.resolved(for: context)
        guard !config.passthrough else { return .passUnchanged }
        if config.invertVertical { negate(event, axis: .vertical) }
        if config.invertHorizontal { negate(event, axis: .horizontal) }
        return .passUnchanged
    }

    private enum Axis { case vertical, horizontal }

    private func negate(_ event: CGEvent, axis: Axis) {
        let line: CGEventField = axis == .vertical ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
        let point: CGEventField = axis == .vertical ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2
        let fixed: CGEventField = axis == .vertical ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2

        event.setIntegerValueField(line, value: -event.getIntegerValueField(line))
        event.setIntegerValueField(point, value: -event.getIntegerValueField(point))
        event.setDoubleValueField(fixed, value: -event.getDoubleValueField(fixed))
    }
}
