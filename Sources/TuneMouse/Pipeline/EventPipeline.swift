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
        let context = ProcessingContext(frontmostBundleID: contextProvider.currentBundleID)
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
