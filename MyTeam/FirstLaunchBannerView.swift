import SwiftUI

// MARK: - FirstLaunchBannerView
// 첫 실행, no-key, offline, connector-limited 상태를 표시하는 배너

struct FirstLaunchBannerView: View {
    let state: FirstLaunchState
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var bannerConfig: (icon: String, title: String, message: String, accentColor: Color) {
        switch state.capabilityMode {
        case .localOnly:
            if state.isOffline {
                return ("wifi.slash", "네트워크 연결 없음",
                    "네트워크 연결이 없어 AI 응답은 제한됩니다.", .red)
            } else {
                // API 키 미연결: 큰 CTA 없이 로컬 기능 안내만
                return ("sparkles", "로컬 기능부터 바로 시작",
                    "회의록 양식, 체크리스트, 파일 읽기, 오늘 할 일은 바로 사용할 수 있습니다.", .blue)
            }
        case .connectorLimited:
            return ("exclamationmark.triangle.fill", "연결 기능 준비 중",
                "Google Calendar 읽기 연결은 준비 중입니다. 메일 발송이나 일정 생성은 자동 실행하지 않습니다.", .yellow)
        case .aiEnabled:
            return ("checkmark.circle.fill", "모든 기능 활성화",
                "AI 기능과 모든 기능을 사용할 수 있습니다.", .green)
        }
    }

    var body: some View {
        let config = bannerConfig

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: config.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(config.accentColor)
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(config.message)
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
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(config.accentColor.opacity(isDarkMode ? 0.15 : 0.08))
            )

            // AI 전용 기능을 눌렀을 때만 짧게 안내 (Settings CTA는 Settings에만)
            if state.capabilityMode == .aiEnabled {
                EmptyView()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(nsColor: NSColor.controlBackgroundColor) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        FirstLaunchBannerView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: false,
                capabilityMode: .localOnly
            ),
            onDismiss: {},
            onOpenSettings: {}
        )

        FirstLaunchBannerView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: true,
                isOffline: true,
                capabilityMode: .localOnly
            ),
            onDismiss: {},
            onOpenSettings: {}
        )

        FirstLaunchBannerView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: true,
                capabilityMode: .connectorLimited
            ),
            onDismiss: {},
            onOpenSettings: {}
        )

        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
