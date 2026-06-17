import SwiftUI
import AppKit

/// 현재 실행 중인 앱 한 개. 오버라이드/매핑 Picker가 공유.
struct RunningApp: Identifiable {
    let id: String      // bundle identifier
    let name: String
    let icon: NSImage?
}

/// 실행 중인 앱 목록 조회. 스크롤 오버라이드·버튼 매핑 Picker가 공유한다.
/// Dock에 뜨는 일반 앱(`.regular`)만, 자기 자신은 제외, 이름순 정렬.
enum RunningApps {
    static func list() -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let id = app.bundleIdentifier, id != "com.tunemouse.TuneMouse" else { return nil }
                return RunningApp(id: id, name: app.localizedName ?? id, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }

    /// bundle id → 사람이 읽는 이름. 실행 중이 아니면(목록에 없으면) id 그대로.
    static func name(for id: String) -> String {
        list().first { $0.id == id }?.name ?? id
    }
}

extension RunningApp {
    /// Picker 항목: 앱 아이콘 + 이름. 아이콘이 없으면 이름만.
    @ViewBuilder var pickerLabel: some View {
        if let icon {
            Label {
                Text(name)
            } icon: {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
        } else {
            Text(name)
        }
    }
}
