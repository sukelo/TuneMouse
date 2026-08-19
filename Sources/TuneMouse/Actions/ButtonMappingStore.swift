import Foundation

/// 단일 매핑: 트리거 → 동작.
struct ButtonMapping: Codable, Equatable, Identifiable {
    var id = UUID()
    var trigger: ButtonTrigger
    var action: ActionType
}

/// 글로벌 + 앱별 오버라이드 구조(Phase 2 ScrollSettings와 동일 패턴).
/// 앱 오버라이드가 있으면 글로벌을 대체(통과=빈 배열, 커스텀=자체 목록).
struct ButtonMappings: Codable, Equatable {
    var global: [ButtonMapping] = []
    var perApp: [String: [ButtonMapping]] = [:]

    func resolved(forBundleID bundleID: String?) -> [ButtonMapping] {
        if let bundleID, let override = perApp[bundleID] { return override }
        return global
    }

    /// 핫패스용 해석 — 오버라이드가 없으면 포커스 앱 조회를 건너뛴다(ScrollSettings와 동일 패턴).
    func resolved(for context: ProcessingContext) -> [ButtonMapping] {
        perApp.isEmpty ? global : resolved(forBundleID: context.targetBundleID)
    }
}

/// 버튼 매핑의 영속화 + 관찰 가능 상태.
@MainActor
final class ButtonMappingStore: ObservableObject {
    @Published var mappings: ButtonMappings {
        didSet { save() }
    }

    private let key = "buttonMappings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ButtonMappings.self, from: data) {
            mappings = decoded
        } else {
            mappings = ButtonMappings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
