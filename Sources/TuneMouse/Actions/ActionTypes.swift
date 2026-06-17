import CoreGraphics
import Carbon.HIToolbox

/// 키 조합: 가상 키코드 + modifier 플래그(CGEventFlags rawValue).
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }

    init(keyCode: Int, modifiers: CGEventFlags) {
        self.keyCode = UInt16(keyCode)
        self.modifiers = modifiers.rawValue
    }
}

extension KeyCombo {
    /// 사람이 읽는 표기(예: ⌘W, ⌃→). 표시는 ANSI 기준 키 이름 테이블 사용.
    var displayString: String {
        var s = ""
        let f = flags
        if f.contains(.maskControl) { s += "⌃" }
        if f.contains(.maskAlternate) { s += "⌥" }
        if f.contains(.maskShift) { s += "⇧" }
        if f.contains(.maskCommand) { s += "⌘" }
        s += KeyNames.name(for: keyCode)
        return s
    }
}

/// 가상 키코드 → 표시 이름(ANSI 기준). 미등록 키는 "key{N}".
enum KeyNames {
    static func name(for keyCode: UInt16) -> String {
        table[Int(keyCode)] ?? "key\(keyCode)"
    }

    private static let table: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "esc", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]
}

/// 동작 종류. v1은 keystroke 중심(대부분의 시스템 동작도 단축키로 환원).
enum ActionType: Codable, Equatable {
    case keystroke(KeyCombo)
}

/// 흔한 동작 프리셋 — 전부 키스트로크로 환원된다.
enum ActionPreset: String, CaseIterable, Identifiable {
    case back, forward, missionControl, appExpose, spaceLeft, spaceRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .back: return "뒤로 (⌘[)"
        case .forward: return "앞으로 (⌘])"
        case .missionControl: return "미션 컨트롤 (⌃↑)"
        case .appExpose: return "앱 익스포제 (⌃↓)"
        case .spaceLeft: return "왼쪽 스페이스 (⌃←)"
        case .spaceRight: return "오른쪽 스페이스 (⌃→)"
        }
    }

    var keyCombo: KeyCombo {
        switch self {
        case .back: return KeyCombo(keyCode: kVK_ANSI_LeftBracket, modifiers: .maskCommand)
        case .forward: return KeyCombo(keyCode: kVK_ANSI_RightBracket, modifiers: .maskCommand)
        case .missionControl: return KeyCombo(keyCode: kVK_UpArrow, modifiers: .maskControl)
        case .appExpose: return KeyCombo(keyCode: kVK_DownArrow, modifiers: .maskControl)
        case .spaceLeft: return KeyCombo(keyCode: kVK_LeftArrow, modifiers: .maskControl)
        case .spaceRight: return KeyCombo(keyCode: kVK_RightArrow, modifiers: .maskControl)
        }
    }

    var action: ActionType { .keystroke(keyCombo) }
}
