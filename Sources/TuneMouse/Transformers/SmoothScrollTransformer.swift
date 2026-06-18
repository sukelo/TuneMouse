import CoreGraphics

/// 부드러운 스크롤 변환기. discrete 휠 입력을 애니메이터에 넘기고 원본을 소비한다.
/// 앱별 부드러움 on/off 지원(frontmost bundle id로 설정 해석).
/// (연속 스크롤은 탭에서 이미 우회되어 여기 도달하지 않음 → 합성 스트림 재처리 없음.)
final class SmoothScrollTransformer: EventTransformer {
    var settings = ScrollSettings()

    private let animator: SmoothScrollAnimator

    init(animator: SmoothScrollAnimator) {
        self.animator = animator
    }

    var isEnabled: Bool {
        settings.global.smoothEnabled || settings.perApp.values.contains { $0.smoothEnabled }
    }

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        guard type == .scrollWheel else { return .passUnchanged }

        let config = settings.resolved(forBundleID: context.targetBundleID)
        guard !config.passthrough, config.smoothEnabled else { return .passUnchanged }

        let lineV = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineH = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        guard lineV != 0 || lineH != 0 else { return .passUnchanged }

        animator.pixelsPerLine = config.smoothStep
        animator.perTickFraction = fraction(from: config.smoothness)
        animator.addLineDelta(vertical: lineV, horizontal: lineH)
        return .discard
    }

    /// smoothness(0..1, 높을수록 부드러움) → 프레임당 소진 비율(0.35 거침 .. 0.08 부드러움).
    private func fraction(from smoothness: Double) -> Double {
        let s = max(0, min(1, smoothness))
        return 0.35 - 0.27 * s
    }
}
