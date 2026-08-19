import CoreGraphics
import Foundation

/// 부드러운 스크롤 애니메이터. 축별 잔여 거리(픽셀)를 누적하고, 메인 런루프 타이머(~60Hz)로
/// 매 프레임 일부를 소진하며 **연속(픽셀) 스크롤 이벤트**를 합성·post 한다.
///
/// 합성 이벤트는 IsContinuous=1 → 우리 탭에서 파이프라인을 우회(재진입/이중 처리 없음).
/// 입력(addLineDelta)과 타이머 모두 메인에서 동작(단일 스레드).
final class SmoothScrollAnimator: NSObject {
    /// 노치당 픽셀 거리.
    var pixelsPerLine = 60.0
    /// 프레임당 소진 비율(작을수록 부드럽고 길다).
    var perTickFraction = 0.2

    private var remainingV = 0.0
    private var remainingH = 0.0
    private var timer: Timer?
    private let source = CGEventSource(stateID: .combinedSessionState)

    /// 라인 delta(부호 포함)를 거리로 변환해 누적하고 루프를 가동한다.
    func addLineDelta(vertical: Double, horizontal: Double) {
        remainingV += vertical * pixelsPerLine
        remainingH += horizontal * pixelsPerLine
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common) // 메뉴/리사이즈 등 트래킹 모드에서도 가동
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 기능 비활성/패닉 키에서 호출 — 잔여 거리를 버리고 즉시 멈춘다.
    /// 이게 없으면 "끔" 이후에도 합성 스크롤이 최대 1초 이상 계속 나간다.
    func reset() {
        remainingV = 0
        remainingH = 0
        stop()
    }

    @objc private func tick() {
        let moveV = consume(&remainingV)
        let moveH = consume(&remainingH)
        if moveV == 0 && moveH == 0 {
            stop()
            return
        }
        postScroll(pixelV: moveV, pixelH: moveH)
    }

    private func consume(_ remaining: inout Double) -> Int32 {
        if abs(remaining) < 0.5 { remaining = 0; return 0 }
        var move = remaining * perTickFraction
        if abs(move) < 1 { move = remaining > 0 ? 1 : -1 } // 꼬리 구간 최소 1px 보장
        let stepInt = move.rounded(.towardZero)
        remaining -= stepInt
        return Int32(stepInt)
    }

    private func postScroll(pixelV: Int32, pixelH: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: pixelV,
            wheel2: pixelH,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1) // 연속 표시 → 탭 우회
        event.post(tap: .cgSessionEventTap)
    }
}
