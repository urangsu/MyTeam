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
            if !state.hasAPIKey {
                return ("key.fill", "API 키 필요",
                    "AI 응답을 사용하려면 설정에서 API 키를 연결해 주세요.", .orange)
            } else if state.isOffline {
                return ("wifi.slash", "네트워크 연결 없음",
                    "네트워크 연결이 없어 AI 응답은 제한됩니다.", .red)
            } else {
                return ("gearshape.fill", "로컬 전용",
                    "지금은 로컬 파일 정리, 문서 템플릿, 스케줄 확인 기능을 사용할 수 있습니다.", .blue)
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

            // 액션 버튼 (API 키 필요한 경우)
            if !state.hasAPIKey && state.capabilityMode == .localOnly {
                HStack(spacing: 10) {
                    Button(action: onOpenSettings) {
                        Label("설정에서 API 키 연결", systemImage: "gear")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onDismiss) {
                        Text("나중에")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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
