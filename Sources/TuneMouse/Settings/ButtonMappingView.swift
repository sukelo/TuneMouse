import SwiftUI
import AppKit
import CoreGraphics

/// 단축키 캡처: 녹화 모드에서 다음 keyDown을 잡아 KeyCombo로 변환.
/// 설정창이 키 윈도우일 때 local monitor로 동작.
@MainActor
final class ShortcutRecorder: ObservableObject {
    @Published var combo: KeyCombo?
    @Published var isRecording = false
    private var monitor: Any?

    func start() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.capture(event)
            return nil // 이벤트 소비(삑 소리/입력 방지)
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func capture(_ event: NSEvent) {
        var flags = CGEventFlags()
        if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        combo = KeyCombo(keyCode: Int(event.keyCode), modifiers: flags)
        stop()
    }
}

/// 버튼 매핑 편집 섹션(v1). 버튼 번호 + 동작 프리셋 + 적용 범위(글로벌/앱별)를 골라 추가.
/// 커스텀 단축키 캡처·버튼 캡처·홀드/더블/드래그는 후속.
struct ButtonMappingSection: View {
    @ObservedObject var store: ButtonMappingStore

    @State private var scopeIsGlobal = true
    @State private var bundleID = ""
    @State private var button = 4
    @State private var preset: ActionPreset = .back
    @State private var usePreset = true
    @StateObject private var recorder = ShortcutRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("버튼 매핑").font(.headline)

            mappingList

            Divider().opacity(0.3)

            addForm
        }
        .onAppear { if bundleID.isEmpty { bundleID = runningApps.first?.id ?? "" } }
    }

    // MARK: 목록

    @ViewBuilder
    private var mappingList: some View {
        let hasAny = !store.mappings.global.isEmpty || store.mappings.perApp.contains { !$0.value.isEmpty }
        if !hasAny {
            Text("매핑 없음").font(.caption).foregroundStyle(.secondary)
        } else {
            ForEach(store.mappings.global) { mapping in
                row(scope: "글로벌", mapping: mapping) { delete(mapping, bundleID: nil) }
            }
            ForEach(store.mappings.perApp.sorted { $0.key < $1.key }, id: \.key) { bundleID, list in
                ForEach(list) { mapping in
                    row(scope: appName(bundleID), mapping: mapping) { delete(mapping, bundleID: bundleID) }
                }
            }
        }
    }

    private func row(scope: String, mapping: ButtonMapping, delete: @escaping () -> Void) -> some View {
        HStack {
            Text("\(scope) · 버튼 \(mapping.trigger.button) → \(actionLabel(mapping.action))")
                .font(.callout)
            Spacer()
            Button(action: delete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 추가 폼

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("적용 범위", selection: $scopeIsGlobal) {
                Text("글로벌").tag(true)
                Text("앱별").tag(false)
            }
            .pickerStyle(.segmented)

            if !scopeIsGlobal {
                Picker("앱", selection: $bundleID) {
                    ForEach(runningApps, id: \.id) { app in Text(app.name).tag(app.id) }
                }
            }

            Picker("버튼", selection: $button) {
                ForEach(3...9, id: \.self) { Text("버튼 \($0)").tag($0) }
            }

            Picker("동작 종류", selection: $usePreset) {
                Text("프리셋").tag(true)
                Text("단축키").tag(false)
            }
            .pickerStyle(.segmented)

            if usePreset {
                Picker("동작", selection: $preset) {
                    ForEach(ActionPreset.allCases) { Text($0.label).tag($0) }
                }
            } else {
                Button(recorderLabel) { recorder.isRecording ? recorder.stop() : recorder.start() }
            }

            Button("매핑 추가") { add() }
                .disabled(addDisabled)
        }
    }

    private var recorderLabel: String {
        if recorder.isRecording { return "키를 누르세요… (취소하려면 다시 클릭)" }
        if let combo = recorder.combo { return "단축키: \(combo.displayString)" }
        return "단축키 캡처"
    }

    private var addDisabled: Bool {
        if !scopeIsGlobal && bundleID.isEmpty { return true }
        if !usePreset && recorder.combo == nil { return true }
        return false
    }

    // MARK: 동작

    private func add() {
        let action: ActionType
        if usePreset {
            action = preset.action
        } else {
            guard let combo = recorder.combo else { return }
            action = .keystroke(combo)
        }
        let mapping = ButtonMapping(trigger: ButtonTrigger(button: Int64(button)), action: action)
        if scopeIsGlobal {
            store.mappings.global.append(mapping)
        } else {
            guard !bundleID.isEmpty else { return }
            store.mappings.perApp[bundleID, default: []].append(mapping)
        }
        recorder.combo = nil
    }

    private func delete(_ mapping: ButtonMapping, bundleID: String?) {
        if let bundleID {
            store.mappings.perApp[bundleID]?.removeAll { $0.id == mapping.id }
            if store.mappings.perApp[bundleID]?.isEmpty == true {
                store.mappings.perApp[bundleID] = nil
            }
        } else {
            store.mappings.global.removeAll { $0.id == mapping.id }
        }
    }

    // MARK: 헬퍼

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

    private func actionLabel(_ action: ActionType) -> String {
        if case .keystroke(let combo) = action,
           let preset = ActionPreset.allCases.first(where: { $0.keyCombo == combo }) {
            return preset.label
        }
        return "키스트로크"
    }
}
