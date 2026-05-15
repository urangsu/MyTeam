import SwiftUI

// MARK: - LocalOnlyModeCardView
// 로컬 전용 모드 상태와 사용 가능한 기능을 표시

struct LocalOnlyModeCardView: View {
    let onOpenSettings: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "hdd.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("로컬 기능만 활성")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("AI 응답이 아직 활성화되지 않았습니다.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 사용 가능한 기능 목록
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "folder.fill", title: "로컬 파일 정리", available: true)
                featureRow(icon: "doc.fill", title: "문서 템플릿", available: true)
                featureRow(icon: "calendar.fill", title: "스케줄 관리", available: true)
                featureRow(icon: "sparkles", title: "AI 응답 (미활성화)", available: false)
            }
            .padding(.vertical, 8)

            // 액션 버튼
            Button(action: onOpenSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12, weight: .semibold))

                    Text("API 키 연결하기")
                        .font(.system(size: 12, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(nsColor: NSColor.controlBackgroundColor) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func featureRow(icon: String, title: String, available: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(available ? .green : .secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(available ? .primary : .secondary)

            Spacer()

            if available {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        LocalOnlyModeCardView(
            onOpenSettings: {}
        )

        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
