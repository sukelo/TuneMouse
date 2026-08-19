import CoreGraphics

/// 순서 있는 변환기 체인. EventTapController에서 단일 `EventProcessor` 로 쓰인다.
/// 활성 변환기를 순서대로 통과시키며, 각 변환기는 in-place 수정(passUnchanged) 또는 교체/소비를 한다.
final class EventPipeline: EventProcessor {
    private let transformers: [EventTransformer]
    private let contextProvider: AppContextProvider

    init(transformers: [EventTransformer], contextProvider: AppContextProvider) {
        self.transformers = transformers
        self.contextProvider = contextProvider
    }

    func process(type: CGEventType, event: CGEvent) -> ProcessResult {
        // 스크롤은 커서 아래 창으로 라우팅되므로 오버라이드도 커서 기준. 그 외(버튼)는 포커스 앱.
        // 해석은 지연 — 앱별 오버라이드가 없으면 변환기가 읽지 않아 창 조회가 아예 안 일어난다.
        let location = event.location
        let context = ProcessingContext { [contextProvider] in
            type == .scrollWheel
                ? contextProvider.bundleID(atScreenPoint: location)
                : contextProvider.currentBundleID
        }
        var current = event
        var replaced = false

        for transformer in transformers where transformer.isEnabled {
            switch transformer.transform(event: current, type: type, context: context) {
            case .passUnchanged:
                continue
            case .transformed(let newEvent):
                current = newEvent
                replaced = true
            case .discard:
                return .discard
            }
        }
        return replaced ? .transformed(current) : .passUnchanged
    }
}
