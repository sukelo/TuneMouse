import os

/// 앱 전역 로깅. Console.app에서 subsystem `com.tunemouse.TuneMouse` 로 필터링.
/// 카테고리는 기능 축이 늘면 함께 확장(tap, scroll, action, override 등).
enum Log {
    private static let subsystem = "com.tunemouse.TuneMouse"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let menu = Logger(subsystem: subsystem, category: "menu")
    static let tap = Logger(subsystem: subsystem, category: "tap")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let action = Logger(subsystem: subsystem, category: "action")
}
