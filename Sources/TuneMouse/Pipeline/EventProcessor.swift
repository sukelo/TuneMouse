import CoreGraphics

/// 이벤트 처리 결과.
enum ProcessResult {
    case passUnchanged          // 원본 통과. **in-place 수정(필드 변경)도 이 케이스** — 동일 객체라 소유권 이동 없음
    case transformed(CGEvent)   // 새로 생성한 이벤트로 교체 (시스템이 소유권을 가져감 → passRetained 처리됨)
    case discard                // 이벤트 소비(재전송 안 함)
}

/// EventTapController가 호출하는 단일 진입점. `EventPipeline` 이 구현한다.
protocol EventProcessor: AnyObject {
    func process(type: CGEventType, event: CGEvent) -> ProcessResult
}
