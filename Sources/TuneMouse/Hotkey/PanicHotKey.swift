import Carbon.HIToolbox

/// 패닉 키 — 전역 단축키로 전체 기능을 즉시 on/off 하는 안전장치.
/// Carbon `RegisterEventHotKey` 사용(시스템 전역, 어느 앱이 앞에 있어도 발동).
/// 기본 조합: ⌃⌥⌘M. 커스터마이즈 UI는 후속 단계.
@MainActor
final class PanicHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), panicHotKeyHandler, 1, &eventType, selfPtr, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x544D_4831 /* 'TMH1' */), id: 1)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_M), modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status == noErr {
            Log.hotkey.notice("패닉 키 등록: ⌃⌥⌘M")
        } else {
            Log.hotkey.error("패닉 키 등록 실패: status=\(status)")
        }
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
