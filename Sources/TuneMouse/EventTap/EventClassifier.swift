import CoreGraphics

/// 이벤트 분류. 핵심 역할: **트랙패드/연속 스크롤을 가공 대상에서 제외**.
enum EventClassifier {
    /// 연속(픽셀 단위) 스크롤이면 트랙패드 또는 Magic Mouse 제스처 → 가공하지 않고 통과.
    /// 물리 휠 마우스는 비연속(라인 단위, isContinuous == 0).
    static func isContinuousScroll(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    }
}
