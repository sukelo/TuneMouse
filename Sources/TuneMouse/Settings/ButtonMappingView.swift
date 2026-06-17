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
        // Esc(modifier 없이)는 캡처 취소로 — 엉뚱한 키가 저장되지 않게. (53 = kVK_Escape)
        if event.keyCode == 53,
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            stop()
            return
        }
        var flags = CGEventFlags()
        if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        combo = KeyCombo(keyCode: Int(event.keyCode), modifiers: flags)
        stop()
    }
}

/// 마우스 버튼 캡처: 녹화 모드에서 다음 `otherMouseDown`을 잡아 버튼 번호로 변환.
/// **좌/우 클릭은 잡지 않는다**(.otherMouseDown만 감시 → 휠클릭=2, 옆버튼=3,4,… 만 캡처).
/// 이로써 사용자가 CG 번호 체계(0-based)를 몰라도 실제 버튼을 눌러 지정할 수 있다.
@MainActor
final class MouseButtonRecorder: ObservableObject {
    @Published var button: Int?
    @Published var isRecording = false
    private var monitor: Any?

    func start() {
        guard !isRecording else { return }
        isRecording = true
        button = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            self?.capture(event)
            return nil // 이벤트 소비
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func capture(_ event: NSEvent) {
        button = event.buttonNumber
        stop()
    }
}

/// 버튼 번호(CGEvent 0-based) → 사람이 읽는 이름. 옆 버튼의 흔한 용도까지 힌트로.
enum MouseButtonNames {
    static func name(_ n: Int) -> String {
        switch n {
        case 2: return "휠 클릭"
        case 3: return "옆 버튼 ①"
        case 4: return "옆 버튼 ②"
        default: return "버튼 \(n)"
        }
    }

    static func hint(_ n: Int) -> String? {
        switch n {
        case 2: return "휠(가운데) 클릭"
        case 3: return "보통 ‘뒤로’ 버튼"
        case 4: return "보통 ‘앞으로’ 버튼"
        default: return nil
        }
    }
}

/// 버튼 매핑 편집 섹션(v1). 버튼을 직접 눌러 지정 + 동작(프리셋/단축키) + 적용 범위(글로벌/앱별).
/// 홀드/더블/드래그 트리거는 후속.
struct ButtonMappingSection: View {
    @ObservedObject var store: ButtonMappingStore

    @State private var scopeIsGlobal = true
    @State private var bundleID = ""
    @State private var preset: ActionPreset = .back
    @State private var usePreset = true
    @StateObject private var recorder = ShortcutRecorder()
    @StateObject private var buttonRecorder = MouseButtonRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            Text("\(scope) · \(MouseButtonNames.name(Int(mapping.trigger.button))) → \(actionLabel(mapping.action))")
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
                    ForEach(runningApps) { app in app.pickerLabel.tag(app.id) }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Button(buttonRecorderLabel) {
                    buttonRecorder.isRecording ? buttonRecorder.stop() : buttonRecorder.start()
                }
                if let b = buttonRecorder.button, let hint = MouseButtonNames.hint(b) {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                } else if !buttonRecorder.isRecording && buttonRecorder.button == nil {
                    Text("리매핑할 옆 버튼/휠 클릭을 누르세요 (좌·우 클릭은 안 잡힘)")
                        .font(.caption).foregroundStyle(.secondary)
                }
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

    private var buttonRecorderLabel: String {
        if buttonRecorder.isRecording { return "버튼을 누르세요… (취소하려면 다시 클릭)" }
        if let b = buttonRecorder.button { return "지정됨: \(MouseButtonNames.name(b))" }
        return "버튼 지정하기"
    }

    private var recorderLabel: String {
        if recorder.isRecording { return "키를 누르세요… (취소하려면 다시 클릭)" }
        if let combo = recorder.combo { return "단축키: \(combo.displayString)" }
        return "단축키 캡처"
    }

    private var addDisabled: Bool {
        if buttonRecorder.button == nil { return true }
        if !scopeIsGlobal && bundleID.isEmpty { return true }
        if !usePreset && recorder.combo == nil { return true }
        return false
    }

    // MARK: 동작

    private func add() {
        guard let button = buttonRecorder.button else { return }
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
        buttonRecorder.button = nil
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

    private var runningApps: [RunningApp] { RunningApps.list() }

    private func appName(_ id: String) -> String { RunningApps.name(for: id) }

    private func actionLabel(_ action: ActionType) -> String {
        if case .keystroke(let combo) = action,
           let preset = ActionPreset.allCases.first(where: { $0.keyCombo == combo }) {
            return preset.label
        }
        return "키스트로크"
    }
}
