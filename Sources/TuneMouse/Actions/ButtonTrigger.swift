import Foundation

/// 클릭 종류. v1은 click만. hold/double/drag는 타이밍 상태머신 필요 → 후속.
enum ClickKind: String, Codable {
    case click
    // case hold, double, drag (후속)
}

/// 버튼 트리거: 버튼 번호 + 클릭 종류 + 요구 modifier(CGEventFlags rawValue의 device-independent 부분).
struct ButtonTrigger: Codable, Equatable {
    var button: Int64
    var clickKind: ClickKind = .click
    var modifiers: UInt64 = 0
}
