import SwiftUI

/// 설정 화면의 카드 컨테이너 — 아이콘 + 제목(+부제) 헤더와 내용을 하나의 시각적 그룹으로 묶는다.
/// 평평한 텍스트+구분선 대신 카드로 묶어 "정돈된" 인상을 준다.
struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String, systemImage: String, subtitle: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}
