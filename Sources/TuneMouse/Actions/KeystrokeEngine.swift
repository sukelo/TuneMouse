import CoreGraphics

/// 키스트로크 합성/발사. 키보드는 탭하지 않으므로 합성 키가 우리 탭에 재유입되지 않는다(재진입 안전).
enum KeystrokeEngine {
    static func fire(_ combo: KeyCombo) {
        // 버튼 발사는 드물어 호출마다 소스 생성(전역 가변 상태 회피)
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
        else {
            Log.action.error("키 이벤트 생성 실패 (key=\(combo.keyCode))")
            return
        }
        down.flags = combo.flags
        up.flags = combo.flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        Log.action.debug("키스트로크 발사: key=\(combo.keyCode) flags=\(combo.modifiers)")
    }
}
