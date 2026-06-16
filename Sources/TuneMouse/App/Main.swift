import AppKit

@main
struct Main {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        // Dock 아이콘 없이 메뉴바 전용으로 동작 (LSUIElement와 함께 이중 보장)
        app.setActivationPolicy(.accessory)

        // delegate는 약한 참조라 run() 동안 살아있도록 지역 변수로 보유
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
