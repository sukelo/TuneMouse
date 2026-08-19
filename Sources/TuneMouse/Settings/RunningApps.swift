import SwiftUI
import AppKit

/// 앱 한 개의 표시 정보. 오버라이드/매핑 Picker가 공유.
struct RunningApp: Identifiable {
    let id: String      // bundle identifier
    let name: String
    let icon: NSImage?
}

/// 실행 중인 앱 목록 + 임의 bundle id의 이름/아이콘 해석을 담당하는 모델.
/// 스크롤 오버라이드·버튼 매핑 뷰가 각각 `@StateObject`로 보유한다.
/// - 실행 목록은 `refresh()`로 갱신(설정창은 떠 있는 동안 프로세스가 바뀔 수 있어 수동 새로고침 제공).
/// - 실행 중이 아닌 앱은 설치 경로로 이름/아이콘을 복원(저장된 오버라이드 대상이 종료돼도 raw id가 안 보이게).
@MainActor
final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    /// 설치된 앱 조회 결과 캐시(경로/아이콘은 잘 안 바뀌므로 bundle id 단위로 보관).
    private var installedCache: [String: RunningApp] = [:]

    init() { refresh() }

    /// 현재 실행 중인 일반 앱(`.regular`)만, 자기 자신 제외, 이름순.
    func refresh() {
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
                return RunningApp(id: id, name: app.localizedName ?? id, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }

    /// 임의 bundle id → 표시 정보. 실행 중이면 그걸, 아니면 설치된 앱을 조회(캐시), 둘 다 없으면 id 그대로.
    func info(for id: String) -> RunningApp {
        if let running = apps.first(where: { $0.id == id }) { return running }
        if let cached = installedCache[id] { return cached }
        let resolved = Self.lookupInstalled(id)
        installedCache[id] = resolved
        return resolved
    }

    private static func lookupInstalled(_ id: String) -> RunningApp {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return RunningApp(id: id, name: id, icon: nil)
        }
        let display = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return RunningApp(id: id, name: display.isEmpty ? id : display, icon: icon)
    }
}

/// 앱 아이콘 16pt. 없으면 점선 플레이스홀더.
struct AppIcon: View {
    let image: NSImage?
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}

extension RunningApp {
    /// Picker 항목 / 목록 행에서 쓰는 아이콘+이름 라벨.
    var label: some View {
        Label { Text(name) } icon: { AppIcon(image: icon) }
    }
}
