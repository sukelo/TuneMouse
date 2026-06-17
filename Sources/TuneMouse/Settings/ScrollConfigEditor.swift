import SwiftUI

/// 스크롤 설정(`ScrollConfig`) 편집 컨트롤. 전역 기본과 앱별 오버라이드가 **같은 UI를 공유**한다.
/// `includePassthrough`: 앱별일 때만 "이 앱에서는 끄기" 토글 노출. 켜지면 나머지 비활성.
/// 카피는 사용자 언어 기준(개발 용어 노출 금지). 슬라이더는 숫자 대신 의미 라벨(느림↔빠름).
struct ScrollConfigEditor: View {
    @Binding var config: ScrollConfig
    var includePassthrough = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if includePassthrough {
                Toggle(isOn: $config.passthrough) {
                    Text("이 앱에서는 끄기")
                    Text("스크롤을 가공하지 않고 그대로 둡니다")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Group {
                Toggle("세로 방향 뒤집기", isOn: $config.invertVertical)
                Toggle("가로 방향 뒤집기", isOn: $config.invertHorizontal)

                // 스크롤 속도
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("스크롤 속도")
                        Spacer()
                        Text(String(format: "%.2f×", config.speedMultiplier))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    labeledSlider(value: $config.speedMultiplier, in: 0.25...5.0,
                                  low: "느림", high: "빠름")
                }

                // 윈도우식 균일 스크롤 (가속 제거)
                Toggle(isOn: $config.linearScroll) {
                    Text("윈도우식 균일 스크롤")
                    Text("빨리 굴려도 가속 없이 일정하게")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if config.linearScroll {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("한 칸당 이동 거리").font(.caption).foregroundStyle(.secondary)
                        labeledSlider(value: $config.pixelsPerNotch, in: 10...120,
                                      low: "조금", high: "많이")
                    }
                    .padding(.leading, 2)
                }

                // 부드러운 스크롤
                Toggle(isOn: $config.smoothEnabled) {
                    Text("부드러운 스크롤")
                    Text("계단식 대신 매끄럽게 흐르도록")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if config.smoothEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("한 번에 가는 거리").font(.caption).foregroundStyle(.secondary)
                            labeledSlider(value: $config.smoothStep, in: 20...200,
                                          low: "짧게", high: "길게")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("부드러운 정도").font(.caption).foregroundStyle(.secondary)
                            labeledSlider(value: $config.smoothness, in: 0...1,
                                          low: "약하게", high: "강하게")
                        }
                    }
                    .padding(.leading, 2)
                }
            }
            // 통과 모드면 나머지 컨트롤은 의미 없으므로 비활성.
            .disabled(includePassthrough && config.passthrough)
        }
    }

    /// 양 끝에 의미 라벨이 붙은 슬라이더(숫자 대신 느낌으로 이해).
    private func labeledSlider(value: Binding<Double>, in range: ClosedRange<Double>,
                              low: String, high: String) -> some View {
        HStack(spacing: 8) {
            Text(low).font(.caption2).foregroundStyle(.tertiary)
            Slider(value: value, in: range)
            Text(high).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
