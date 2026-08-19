import CoreGraphics

/// 이벤트 분류. 핵심 역할: **트랙패드/연속 스크롤을 가공 대상에서 제외**.
enum EventClassifier {
    /// 연속(픽셀 단위) 스크롤이면 트랙패드 또는 Magic Mouse 제스처 → 가공하지 않고 통과.
    /// 물리 휠 마우스는 비연속(라인 단위, isContinuous == 0).
    static func isContinuousScroll(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    }
}

/// 우리가 합성해 post 한 이벤트의 표식.
///
/// 균일 스크롤·부드러운 스크롤은 연속 픽셀 이벤트를 합성해 다시 시스템에 넣는다. 이게 우리 탭에
/// 되돌아와 또 합성되면 **콜백 안에서 동기 재귀 → 스택 오버플로**가 되고, 그동안 시스템 전체
/// 마우스 입력이 콜백 뒤에 막힌다.
///
/// 실제 우회는 `isContinuousScroll`이 이미 처리하지만, 그 비트는 **트랙패드 판별과 같은 비트**라
/// 하나가 무너지면 둘 다 무너진다. 그래서 우리 소유의 독립적인 표식을 하나 더 찍어 이중으로 막는다.
enum SynthesizedEvent {
    /// 'TMS\0' — 다른 앱과 겹칠 이유가 없는 값.
    private static let marker: Int64 = 0x544D_5300

    /// 합성 직후 호출 — 이 이벤트가 우리 것임을 표시.
    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
    }

    /// 탭 콜백 진입 시 호출 — 우리가 만든 이벤트면 가공하지 않고 통과시킨다.
    static func isOurs(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}
