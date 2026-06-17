import SwiftUI
import AppKit

/// 앱별 스크롤 설정 섹션. 지정 앱에서 방향/속도/가속제거/부드러움을 개별 편집하거나,
/// "통과"로 스크롤 가공 전체를 끈다. 전역과 동일한 `ScrollConfigEditor`를 공유.
/// 오버라이드는 글로벌을 **대체**(병합 아님)하므로, 추가 시 **현재 전역값을 복사**해 시작한다.
struct AppScrollOverrideSection: View {
    @ObservedObject var store: ScrollSettingsStore
    @StateObject private var apps = RunningAppsModel()

    @State private var bundleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.settings.perApp.isEmpty {
                Text("아래에서 앱을 골라 추가하세요").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.settings.perApp.sorted { $0.key < $1.key }, id: \.key) { id, config in
                    DisclosureGroup {
                        ScrollConfigEditor(config: configBinding(id), includePassthrough: true)
                            .padding(.top, 4)
                    } label: {
                        HStack {
                            apps.info(for: id).label.font(.callout)
                            Spacer()
                            Text(summary(config))
                                .font(.caption).foregroundStyle(.secondary)
                            Button { store.settings.perApp[id] = nil } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Picker("앱", selection: $bundleID) {
                    ForEach(apps.apps) { app in app.label.tag(app.id) }
                }
                Button { apps.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("실행 중인 앱 목록 새로고침")
                Button("설정 추가") { add() }
                    .disabled(bundleID.isEmpty || store.settings.perApp[bundleID] != nil)
            }
        }
        .onAppear { if bundleID.isEmpty { bundleID = apps.apps.first?.id ?? "" } }
    }

    /// 새 오버라이드는 현재 전역값을 복사해 시작(교체 모델 → "전역과 같게 두고 다른 것만 수정").
    private func add() {
        guard !bundleID.isEmpty, store.settings.perApp[bundleID] == nil else { return }
        store.settings.perApp[bundleID] = store.settings.global
    }

    private func configBinding(_ id: String) -> Binding<ScrollConfig> {
        Binding(
            // 항목 제거 직후 stale id로 호출돼도 빈 기본값 대신 전역값으로(교체 모델 일관).
            get: { store.settings.perApp[id] ?? store.settings.global },
            set: { store.settings.perApp[id] = $0 }
        )
    }

    /// 헤더에 한 줄 상태 요약.
    private func summary(_ c: ScrollConfig) -> String {
        if c.passthrough { return "이 앱에서는 끔" }
        var parts: [String] = []
        if c.invertVertical || c.invertHorizontal { parts.append("방향 뒤집기") }
        if c.speedMultiplier != 1.0 { parts.append(String(format: "속도 %.2g×", c.speedMultiplier)) }
        if c.linearScroll { parts.append("균일 스크롤") }
        if c.smoothEnabled { parts.append("부드럽게") }
        return parts.isEmpty ? "기본과 동일" : parts.joined(separator: "·")
    }
}
