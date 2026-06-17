import SwiftUI
import AppKit

/// 앱별 스크롤 예외 섹션(v1). 지정 앱에서 스크롤 가공을 끄는 "통과" 토글이 핵심.
/// (앱별 방향/속도/부드러움 개별 값 편집은 후속 — 엔진은 이미 지원.)
struct AppScrollOverrideSection: View {
    @ObservedObject var store: ScrollSettingsStore

    @State private var bundleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("앱별 스크롤 예외").font(.headline)

            if store.settings.perApp.isEmpty {
                Text("앱별 설정 없음").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.settings.perApp.sorted { $0.key < $1.key }, id: \.key) { id, _ in
                    HStack {
                        Text(appName(id)).font(.callout)
                        Spacer()
                        Toggle("스크롤 끄기", isOn: passthroughBinding(id))
                        Button { store.settings.perApp[id] = nil } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Picker("앱", selection: $bundleID) {
                    ForEach(runningApps, id: \.id) { app in Text(app.name).tag(app.id) }
                }
                Button("예외 추가") { add() }
                    .disabled(bundleID.isEmpty || store.settings.perApp[bundleID] != nil)
            }
        }
        .onAppear { if bundleID.isEmpty { bundleID = runningApps.first?.id ?? "" } }
    }

    private func add() {
        guard !bundleID.isEmpty, store.settings.perApp[bundleID] == nil else { return }
        var config = ScrollConfig()
        config.passthrough = true // 기본 용도: 해당 앱에서 스크롤 가공 끄기
        store.settings.perApp[bundleID] = config
    }

    private func passthroughBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.settings.perApp[id]?.passthrough ?? false },
            set: { newValue in
                var config = store.settings.perApp[id] ?? ScrollConfig()
                config.passthrough = newValue
                store.settings.perApp[id] = config
            }
        )
    }

    private var runningApps: [(id: String, name: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (id: String, name: String)? in
                guard let id = app.bundleIdentifier, id != "com.tunemouse.TuneMouse" else { return nil }
                return (id, app.localizedName ?? id)
            }
            .sorted { $0.name < $1.name }
    }

    private func appName(_ id: String) -> String {
        runningApps.first { $0.id == id }?.name ?? id
    }
}
