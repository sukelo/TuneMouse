import Carbon.HIToolbox

/// 패닉 키 — 전역 단축키로 전체 기능을 즉시 on/off 하는 안전장치.
/// Carbon `RegisterEventHotKey` 사용(시스템 전역, 어느 앱이 앞에 있어도 발동).
/// 기본 조합: ⌃⌥⌘M. 커스터마이즈 UI는 후속 단계.
@MainActor
final class PanicHotKey {
    // Carbon 핸들: 생성·해제 모두 메인에서만 일어나므로 실제 경합은 없다.
    // `nonisolated(unsafe)`인 이유는 deinit(비격리)에서 정리해야 하기 때문 —
    // 격리된 저장 프로퍼티는 deinit에서 읽을 수 없다.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private let onTrigger: () -> Void

    /// 사람이 읽는 조합 이름 — UI가 하드코딩하지 않도록 여기서 제공.
    static let displayName = "⌃⌥⌘M"

    /// 실제로 등록에 성공했는지. **안전장치이므로 실패를 조용히 넘기면 안 된다** —
    /// 다른 앱이 같은 조합을 선점했거나 핸들러 설치가 실패하면 패닉 키는 죽은 채로 남는데,
    /// UI가 그걸 계속 광고하면 사용자는 있지도 않은 탈출구를 믿게 된다.
    private(set) var isRegistered = false

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return isRegistered }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // 핸들러 설치가 실패하면 핫키는 등록돼도 콜백이 오지 않는다 — 반드시 확인할 것.
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(), panicHotKeyHandler, 1, &eventType, selfPtr, &handlerRef
        )
        guard handlerStatus == noErr else {
            Log.hotkey.error("패닉 키 핸들러 설치 실패: status=\(handlerStatus) — 패닉 키를 쓸 수 없습니다")
            isRegistered = false
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x544D_4831 /* 'TMH1' */), id: 1)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_M), modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status == noErr {
            isRegistered = true
            Log.hotkey.notice("패닉 키 등록: \(Self.displayName, privacy: .public)")
        } else {
            isRegistered = false
            hotKeyRef = nil
            Log.hotkey.error("""
                패닉 키 등록 실패: status=\(status) — 다른 앱이 \(Self.displayName, privacy: .public)을 \
                선점했을 수 있습니다. 메뉴바 토글로 끄고 켤 수 있습니다.
                """)
        }
        return isRegistered
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        isRegistered = false
    }

    /// Carbon 핸들러에 넘긴 포인터는 unretained — 등록된 채 해제되면 C 콜백에서 use-after-free.
    /// (`unregister()`는 MainActor 격리라 deinit에서 부를 수 없어 정리를 인라인한다.)
    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    fileprivate func fire() {
        Log.hotkey.notice("패닉 키 발동 → 기능 토글")
        onTrigger()
    }
}

/// Carbon 이벤트 핸들러 트램펄린. 메인 스레드에서 디스패치되므로 assumeIsolated로 MainActor 진입.
private func panicHotKeyHandler(next: EventHandlerCallRef?,
                                event: EventRef?,
                                userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let hotKey = Unmanaged<PanicHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        hotKey.fire()
    }
    return noErr
}
