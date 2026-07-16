import SwiftUI

// MARK: - OnboardingCardView
// 첫 실행 시 하나의 카드로 상태별 메시지를 표시한다.
// FirstLaunchBannerView + LocalOnlyModeCardView 통합 (WP1).
// 동시에 2개 이상의 온보딩 표면이 뜨지 않는다.

struct OnboardingCardView: View {
    let state: FirstLaunchState
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 (아이콘 + 제목 + 닫기)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("안내 닫기")
                .accessibilityLabel("안내 닫기")
            }

            // localOnly + API 키 없음: 사용 가능한 기능 목록
            if state.capabilityMode == .localOnly && !state.hasAPIKey && !state.isOffline {
                VStack(alignment: .leading, spacing: 6) {
                    featureRow(icon: "doc.text.fill", title: "회의록·체크리스트 양식", available: true)
                    featureRow(icon: "folder.fill", title: "파일 읽기·정리", available: true)
                    featureRow(icon: "calendar", title: "오늘 할 일", available: true)
                    featureRow(icon: "sparkles", title: "AI 대화 (설정에서 활성화)", available: false)
                }
                .padding(.vertical, 4)

                // Settings로 이동하는 작은 텍스트 링크 (큰 CTA 버튼이 아님)
                Button(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("설정에서 AI 연결")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(nsColor: NSColor.controlBackgroundColor) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 상태별 속성

    private var iconName: String {
        FirstLaunchPresentation.content(for: state).iconName
    }

    private var title: String {
        FirstLaunchPresentation.content(for: state).title
    }

    private var subtitle: String {
        FirstLaunchPresentation.content(for: state).subtitle
    }

    private var accentColor: Color {
        switch state.capabilityMode {
        case .localOnly:
            return state.isOffline ? .red : .blue
        case .connectorLimited:
            return .yellow
        case .aiEnabled:
            return .green
        }
    }

    private func featureRow(icon: String, title: String, available: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(available ? .green : .secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(available ? .primary : .secondary)
            Spacer()
            if available {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 6)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingCardView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: false,
                capabilityMode: .localOnly
            ),
            onDismiss: {},
            onOpenSettings: {}
        )

        OnboardingCardView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: true,
                isOffline: true,
                capabilityMode: .localOnly
            ),
            onDismiss: {},
            onOpenSettings: {}
        )

        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
