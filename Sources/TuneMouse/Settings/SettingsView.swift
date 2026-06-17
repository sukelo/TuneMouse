import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var scrollSettings: ScrollSettingsStore
    @ObservedObject var buttonMappings: ButtonMappingStore

    // 창이 떠 있는 동안 권한 상태를 주기적으로 갱신 (시스템 설정에서 허용하면 즉시 반영)
    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // 권한 미허용이면 모든 탭 위에 항상 보이게 — 없으면 아무것도 동작하지 않으므로.
            if !appState.hasAccessibility {
                permissionBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            TabView {
                generalTab.tabItem { Label("일반", systemImage: "gearshape") }
                scrollTab.tabItem { Label("스크롤", systemImage: "computermouse") }
                buttonsTab.tabItem { Label("버튼", systemImage: "cursorarrow.click") }
            }
            .padding(.top, 10)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            appState.refreshAccessibility()
            appState.refreshLaunchAtLogin()
        }
        .onReceive(permissionTimer) { _ in
            appState.refreshAccessibility()
        }
    }

    // MARK: 탭 공통 스크롤 컨테이너

    private func tabBody<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(spacing: 14) { content() }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 마스터 스위치가 꺼져 있을 때 탭 상단에 보여줄 안내.
    @ViewBuilder
    private var offHint: some View {
        if !appState.isEnabled {
            Label("TuneMouse가 꺼져 있어 지금은 적용되지 않아요", systemImage: "moon.zzz")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 일반 탭

    private var generalTab: some View {
        tabBody {
            SettingsCard("전원", systemImage: "power") {
                Toggle(isOn: $appState.isEnabled) {
                    Text("TuneMouse 켜기")
                    Text("전체 기능 켜기/끄기 · 패닉키 ⌃⌥⌘M")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Toggle("로그인 시 자동 시작", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                ))
            }

            SettingsCard("접근성 권한", systemImage: "lock.shield") {
                if appState.hasAccessibility {
                    Label("허용됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("마우스 휠·버튼을 가공하려면 접근성 권한이 필요합니다.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("시스템 설정 열기") {
                        AccessibilityPermission.promptIfNeeded()
                        AccessibilityPermission.openSystemSettings()
                    }
                }
            }
        }
    }

    // MARK: 스크롤 탭

    private var scrollTab: some View {
        tabBody {
            offHint
            Group {
                SettingsCard("스크롤", systemImage: "computermouse",
                             subtitle: "모든 앱에 적용되는 기본") {
                    ScrollConfigEditor(config: $scrollSettings.settings.global)
                    Divider()
                    Button("기본값으로") { scrollSettings.settings.global = ScrollConfig() }
                        .font(.caption)
                }

                SettingsCard("앱별 스크롤", systemImage: "macwindow.on.rectangle",
                             subtitle: "특정 앱만 다르게 (없으면 기본 사용)") {
                    AppScrollOverrideSection(store: scrollSettings)
                }
            }
            .opacity(appState.isEnabled ? 1 : 0.55)
        }
    }

    // MARK: 버튼 탭

    private var buttonsTab: some View {
        tabBody {
            offHint
            SettingsCard("버튼 매핑", systemImage: "cursorarrow.click",
                         subtitle: "옆 버튼·휠 클릭에 동작 연결") {
                ButtonMappingSection(store: buttonMappings)
            }
            .opacity(appState.isEnabled ? 1 : 0.55)
        }
    }

    // MARK: 접근성 권한 배너 (미허용 시 전 탭 상단)

    @ViewBuilder
    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("접근성 권한이 필요합니다").font(.callout).bold()
                Text("허용해야 마우스 가공이 동작해요")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("시스템 설정 열기") {
                AccessibilityPermission.promptIfNeeded()
                AccessibilityPermission.openSystemSettings()
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
