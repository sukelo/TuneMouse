import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var scrollSettings: ScrollSettingsStore
    @ObservedObject var buttonMappings: ButtonMappingStore

    // 창이 떠 있는 동안 권한 상태를 주기적으로 갱신 (시스템 설정에서 허용하면 즉시 반영)
    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TuneMouse")
                    .font(.title2).bold()

                // 권한 미허용이면 가장 먼저 눈에 띄게 — 없으면 아무것도 안 동작하므로 최상단.
                permissionBanner

                masterSwitch

                Divider()

                // 마스터 스위치가 꺼져 있으면 아래 설정은 적용되지 않음을 시각적으로 표시.
                Group {
                    if !appState.isEnabled {
                        Label("꺼져 있어요 — 위 스위치를 켜면 아래 설정이 적용됩니다",
                              systemImage: "moon.zzz")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    scrollSection

                    Divider()

                    AppScrollOverrideSection(store: scrollSettings)

                    Divider()

                    ButtonMappingSection(store: buttonMappings)
                }
                .opacity(appState.isEnabled ? 1 : 0.5)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 460, height: 560)
        .onAppear {
            appState.refreshAccessibility()
            appState.refreshLaunchAtLogin()
        }
        .onReceive(permissionTimer) { _ in
            appState.refreshAccessibility()
        }
    }

    // MARK: 마스터 스위치 (전체 기능 on/off)

    @ViewBuilder
    private var masterSwitch: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $appState.isEnabled) {
                Text("TuneMouse 켜기").font(.headline)
                Text("전체 기능 켜기/끄기 · 패닉키 ⌃⌥⌘M")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("로그인 시 자동 시작", isOn: Binding(
                get: { appState.launchAtLogin },
                set: { appState.setLaunchAtLogin($0) }
            ))
            .font(.callout)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: 스크롤 (전역 기본)

    @ViewBuilder
    private var scrollSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("스크롤").font(.headline)
                Text("모든 앱에 적용되는 기본 설정")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ScrollConfigEditor(config: $scrollSettings.settings.global)

            Button("기본값으로") {
                scrollSettings.settings.global = ScrollConfig()
            }
            .font(.caption)
        }
    }

    // MARK: 접근성 권한 배너

    @ViewBuilder
    private var permissionBanner: some View {
        if !appState.hasAccessibility {
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
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("접근성 권한 허용됨").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
