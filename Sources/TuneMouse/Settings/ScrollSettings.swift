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

    /// 값 범위 — UI 슬라이더가 지키는 범위와 같다. 디코드 시에도 강제해야 하는 이유:
    /// 설정은 UserDefaults의 JSON이라 손으로 편집할 수 있고, 하류에서 `Int32(...)` 변환이
    /// 일어난다. 범위를 벗어난 값이나 NaN이 들어오면 그 변환이 **트랩(크래시)** 한다.
    private enum Limits {
        static let speed = 0.1...10.0
        static let pixelsPerNotch = 1.0...500.0
        static let smoothStep = 1.0...500.0
        static let smoothness = 0.0...1.0
    }

    /// NaN/무한대는 기본값으로, 나머지는 범위로 클램프.
    private static func sanitize(_ value: Double, _ range: ClosedRange<Double>, default fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // 구버전 저장본(누락 키) 호환: 누락 키는 기본값. 숫자 값은 전부 sanitize.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        invertVertical = try c.decodeIfPresent(Bool.self, forKey: .invertVertical) ?? false
        invertHorizontal = try c.decodeIfPresent(Bool.self, forKey: .invertHorizontal) ?? false
        linearScroll = try c.decodeIfPresent(Bool.self, forKey: .linearScroll) ?? false
        smoothEnabled = try c.decodeIfPresent(Bool.self, forKey: .smoothEnabled) ?? false
        passthrough = try c.decodeIfPresent(Bool.self, forKey: .passthrough) ?? false

        speedMultiplier = Self.sanitize(
            try c.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0, Limits.speed, default: 1.0)
        pixelsPerNotch = Self.sanitize(
            try c.decodeIfPresent(Double.self, forKey: .pixelsPerNotch) ?? 40.0, Limits.pixelsPerNotch, default: 40.0)
        smoothStep = Self.sanitize(
            try c.decodeIfPresent(Double.self, forKey: .smoothStep) ?? 60.0, Limits.smoothStep, default: 60.0)
        smoothness = Self.sanitize(
            try c.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5, Limits.smoothness, default: 0.5)
    }
}

/// 글로벌 기본 + 앱별 오버라이드 구조(SPEC의 데이터 모델 원칙).
/// Phase 2는 global만 사용. perApp/오버라이드 UI는 후속 단계.
struct ScrollSettings: Codable, Equatable, DefaultInitializable {
    var global = ScrollConfig()
    var perApp: [String: ScrollConfig] = [:]   // bundleID → override (후속)

    /// 적용할 설정 해석: 앱 오버라이드가 있으면 그것, 없으면 글로벌.
    func resolved(forBundleID bundleID: String?) -> ScrollConfig {
        if let bundleID, let override = perApp[bundleID] { return override }
        return global
    }

    /// 핫패스용 해석. 오버라이드가 하나도 없으면 `targetBundleID`를 **읽지 않아**
    /// 커서-앱 창 조회(WindowServer 동기 IPC)를 건너뛴다.
    func resolved(for context: ProcessingContext) -> ScrollConfig {
        perApp.isEmpty ? global : resolved(forBundleID: context.targetBundleID)
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
        settings = SettingsStorage.load(ScrollSettings.self, key: key, label: "스크롤 설정")
    }

    private func save() {
        SettingsStorage.save(settings, key: key, label: "스크롤 설정")
    }
}
