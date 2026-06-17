import Foundation

/// 스크롤 설정 값 묶음(글로벌 기본 또는 앱별 오버라이드에 공통).
struct ScrollConfig: Codable, Equatable {
    var invertVertical = false
    var invertHorizontal = false
    var speedMultiplier = 1.0
}

/// 글로벌 기본 + 앱별 오버라이드 구조(SPEC의 데이터 모델 원칙).
/// Phase 2는 global만 사용. perApp/오버라이드 UI는 후속 단계.
struct ScrollSettings: Codable, Equatable {
    var global = ScrollConfig()
    var perApp: [String: ScrollConfig] = [:]   // bundleID → override (후속)

    /// 적용할 설정 해석: 앱 오버라이드가 있으면 그것, 없으면 글로벌.
    func resolved(forBundleID bundleID: String?) -> ScrollConfig {
        if let bundleID, let override = perApp[bundleID] { return override }
        return global
    }
}

/// 스크롤 설정의 영속화(UserDefaults + JSON) + 관찰 가능 상태.
@MainActor
final class ScrollSettingsStore: ObservableObject {
    @Published var settings: ScrollSettings {
        didSet { save() }
    }

    private let key = "scrollSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ScrollSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ScrollSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
