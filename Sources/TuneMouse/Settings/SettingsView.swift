import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var scrollSettings: ScrollSettingsStore

    // 창이 떠 있는 동안 권한 상태를 주기적으로 갱신 (시스템 설정에서 허용하면 즉시 반영)
    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TuneMouse")
                    .font(.title2).bold()

                Divider()

                Toggle("기능 활성화", isOn: $appState.isEnabled)
                Toggle("로그인 시 자동 시작", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                ))

                Divider()

                scrollSection

                Divider()

                permissionSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 440, height: 460)
        .onAppear {
            appState.refreshAccessibility()
            appState.refreshLaunchAtLogin()
        }
        .onReceive(permissionTimer) { _ in
            appState.refreshAccessibility()
        }
    }

    @ViewBuilder
    private var scrollSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("스크롤")
                .font(.headline)

            Toggle("세로 방향 반전", isOn: $scrollSettings.settings.global.invertVertical)
            Toggle("가로 방향 반전", isOn: $scrollSettings.settings.global.invertHorizontal)

            HStack {
                Text("속도")
                Slider(value: $scrollSettings.settings.global.speedMultiplier, in: 0.25...5.0)
                Text(String(format: "%.2f×", scrollSettings.settings.global.speedMultiplier))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            Button("기본값으로") {
                scrollSettings.settings.global = ScrollConfig()
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("접근성 권한")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: appState.hasAccessibility
                      ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(appState.hasAccessibility ? .green : .orange)
                Text(appState.hasAccessibility ? "허용됨" : "허용 필요")
                    .foregroundStyle(appState.hasAccessibility ? .primary : .secondary)
            }

            if !appState.hasAccessibility {
                Text("마우스 이벤트를 가공하려면 접근성 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("시스템 설정 열기") {
                    AccessibilityPermission.promptIfNeeded()
                    AccessibilityPermission.openSystemSettings()
                }
            }
        }
    }
}
