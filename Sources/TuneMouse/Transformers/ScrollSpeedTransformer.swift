import CoreGraphics

/// 스크롤 속도 배율. delta를 multiplier배. 분수 배율에서 정수 라인 delta가 0이 되는 문제는
/// 축별 누적 잔차(residual)로 보정해 장기적으로 비율을 보존한다.
final class ScrollSpeedTransformer: EventTransformer {
    var multiplier: Double = 1.0

    var isEnabled: Bool { multiplier != 1.0 }

    private var residualVertical: Double = 0
    private var residualHorizontal: Double = 0

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        guard type == .scrollWheel else { return .passUnchanged }
        scale(event, axis: .vertical, residual: &residualVertical)
        scale(event, axis: .horizontal, residual: &residualHorizontal)
        return .passUnchanged
    }

    private enum Axis { case vertical, horizontal }

    private func scale(_ event: CGEvent, axis: Axis, residual: inout Double) {
        let line: CGEventField = axis == .vertical ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
        let point: CGEventField = axis == .vertical ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2
        let fixed: CGEventField = axis == .vertical ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2

        // 라인 delta: 누적 잔차로 0-delta 방지
        let lineValue = event.getIntegerValueField(line)
        if lineValue != 0 {
            // 스크롤 방향이 바뀌면 반대 방향 잔차를 버린다(첫 틱이 먹히는 문제 방지)
            if residual != 0, (lineValue < 0) != (residual < 0) {
                residual = 0
            }
            let scaled = Double(lineValue) * multiplier + residual
            let rounded = scaled.rounded(.towardZero)
            residual = scaled - rounded
            event.setIntegerValueField(line, value: Int64(rounded))
        }
        // point/fixed: 픽셀 단위라 단순 스케일
        let pointValue = event.getIntegerValueField(point)
        if pointValue != 0 {
            event.setIntegerValueField(point, value: Int64((Double(pointValue) * multiplier).rounded()))
        }
        let fixedValue = event.getDoubleValueField(fixed)
        if fixedValue != 0 {
            event.setDoubleValueField(fixed, value: fixedValue * multiplier)
        }
    }
}
