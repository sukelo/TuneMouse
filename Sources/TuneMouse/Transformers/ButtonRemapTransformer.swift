import CoreGraphics

/// 버튼 리매핑 변환기. 매칭 트리거에서 동작을 발사하고 이벤트를 소비한다.
/// **스턱 방지**: 매핑된 버튼은 down/up(및 drag)을 모두 소비. 발사는 down 한 번만.
final class ButtonRemapTransformer: EventTransformer {
    var mappings = ButtonMappings()

    var isEnabled: Bool { !mappings.global.isEmpty || !mappings.perApp.isEmpty }

    /// down을 소비한 버튼 — up/drag도 소비해야 시스템이 눌린 상태로 고착되지 않음.
    private var consumedButtons = Set<Int64>()

    /// 기능 비활성/탭 해제 시 호출 — 소비 상태 초기화(버튼을 누른 채 꺼졌을 때 잔류 방지).
    func reset() { consumedButtons.removeAll() }

    private static let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    /// 리매핑 허용 최소 버튼 번호. 0=좌, 1=우는 **절대 소비하지 않는다** —
    /// 소비되면 시스템 전역에서 클릭이 죽어 우리 메뉴바조차 누를 수 없게 된다.
    /// UI가 막고 있지만 손상/수기 편집된 설정도 있으므로 여기서 하드 가드한다.
    private static let minRemappableButton: Int64 = 2

    func transform(event: CGEvent, type: CGEventType, context: ProcessingContext) -> ProcessResult {
        switch type {
        case .otherMouseDown, .leftMouseDown, .rightMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard button >= Self.minRemappableButton else { return .passUnchanged }
            let active = mappings.resolved(for: context)
            let mods = event.flags.intersection(Self.modifierMask).rawValue
            if let mapping = active.first(where: { $0.trigger.button == button && $0.trigger.modifiers == mods }) {
                fire(mapping.action)
                consumedButtons.insert(button)
                Log.action.debug("버튼 \(button) 매칭 → 발사, 소비")
                return .discard
            }
            return .passUnchanged

        case .otherMouseUp, .leftMouseUp, .rightMouseUp:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            return consumedButtons.remove(button) != nil ? .discard : .passUnchanged

        case .otherMouseDragged, .leftMouseDragged, .rightMouseDragged:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            return consumedButtons.contains(button) ? .discard : .passUnchanged

        default:
            return .passUnchanged
        }
    }

    private func fire(_ action: ActionType) {
        switch action {
        case .keystroke(let combo):
            KeystrokeEngine.fire(combo)
        }
    }
}
