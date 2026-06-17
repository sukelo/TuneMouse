import Foundation

/// 스크롤 설정 값 묶음(글로벌 기본 또는 앱별 오버라이드에 공통).
struct ScrollConfig: Codable, Equatable {
    var invertVertical = false
    var invertHorizontal = false
    var speedMultiplier = 1.0

    // 가속 제거 (선형 스크롤) — true면 OS 휠 가속 곡선을 버리고 노치당 고정 거리로 덮어쓴다.
    var linearScroll = false
    var pixelsPerNotch = 40.0   // 노치당 픽셀(linearScroll일 때만 사용)

    // 부드러운 스크롤 (Phase 4)
    var smoothEnabled = false
    var smoothStep = 60.0       // 노치당 픽셀 거리
    var smoothness = 0.5        // 0..1, 높을수록 부드럽고 길게

    // 앱별 예외 (Phase 5) — true면 그 앱에서 스크롤 가공 전체 skip
    var passthrough = false

    enum CodingKeys: String, CodingKey {
        case invertVertical, invertHorizontal, speedMultiplier
        case linearScroll, pixelsPerNotch
        case smoothEnabled, smoothStep, smoothness, passthrough
    }

    init() {}

    // 구버전 저장본(누락 키) 호환: 누락 키는 기본값.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        invertVertical = try c.decodeIfPresent(Bool.self, forKey: .invertVertical) ?? false
        invertHorizontal = try c.decodeIfPresent(Bool.self, forKey: .invertHorizontal) ?? false
        speedMultiplier = try c.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0
        linearScroll = try c.decodeIfPresent(Bool.self, forKey: .linearScroll) ?? false
        pixelsPerNotch = try c.decodeIfPresent(Double.self, forKey: .pixelsPerNotch) ?? 40.0
        smoothEnabled = try c.decodeIfPresent(Bool.self, forKey: .smoothEnabled) ?? false
        smoothStep = try c.decodeIfPresent(Double.self, forKey: .smoothStep) ?? 60.0
        smoothness = try c.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5
        passthrough = try c.decodeIfPresent(Bool.self, forKey: .passthrough) ?? false
    }
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
