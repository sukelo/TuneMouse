import SwiftUI

/// 스크롤 설정(`ScrollConfig`) 편집 컨트롤. 전역 기본과 앱별 오버라이드가 **같은 UI를 공유**한다.
/// `includePassthrough`: 앱별일 때만 "스크롤 가공 끄기(통과)" 토글 노출. 통과 켜지면 나머지 비활성.
struct ScrollConfigEditor: View {
    @Binding var config: ScrollConfig
    var includePassthrough = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if includePassthrough {
                Toggle("스크롤 가공 끄기 (통과)", isOn: $config.passthrough)
            }

            Group {
                Toggle("세로 방향 반전", isOn: $config.invertVertical)
                Toggle("가로 방향 반전", isOn: $config.invertHorizontal)

                HStack {
                    Text("속도")
                    Slider(value: $config.speedMultiplier, in: 0.25...5.0)
                    Text(String(format: "%.2f×", config.speedMultiplier))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                Toggle("스크롤 가속 제거 (선형)", isOn: $config.linearScroll)

                if config.linearScroll {
                    HStack {
                        Text("노치당 거리")
                        Slider(value: $config.pixelsPerNotch, in: 10...120)
                        Text("\(Int(config.pixelsPerNotch))px")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }

                Toggle("부드러운 스크롤", isOn: $config.smoothEnabled)

                if config.smoothEnabled {
                    HStack {
                        Text("스텝")
                        Slider(value: $config.smoothStep, in: 20...200)
                        Text("\(Int(config.smoothStep))px")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                    HStack {
                        Text("부드러움")
                        Slider(value: $config.smoothness, in: 0...1)
                        Text(String(format: "%.0f%%", config.smoothness * 100))
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            // 통과 모드면 나머지 컨트롤은 의미 없으므로 비활성.
            .disabled(includePassthrough && config.passthrough)
        }
    }
}
