import SwiftUI

// MARK: - FirstLaunchBannerView

struct FirstLaunchBannerView: View {
    let state: FirstLaunchState
    var onDismiss: () -> Void = {}
    var onSettingsTap: () -> Void = {}

    @State private var isVisible = true

    var body: some View {
        if isVisible {
            bannerContent
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var bannerContent: some View {
        if state.shouldShowLocalOnlyGuidance {
            localOnlyBanner
        } else if state.shouldShowOfflineMessage {
            offlineBanner
        } else if state.capabilityMode == .connectorLimited {
            connectorLimitedBanner
        }
    }

    private var localOnlyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                    .frame(width: 20, alignment: .top)

                VStack(alignment: .leading, spacing: 6) {
                    Text("로컬 기능부터 시작하세요")
                        .font(.system(size: 13, weight: .semibold))

                    Text("AI 응답을 사용하려면 설정에서 API 키를 연결해 주세요.\n지금은 로컬 파일 정리, 문서 템플릿, 스케줄 확인 기능부터 사용할 수 있습니다.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.controlBorderColor), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var offlineBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                    .frame(width: 20, alignment: .top)

                VStack(alignment: .leading, spacing: 6) {
                    Text("네트워크 연결 없음")
                        .font(.system(size: 13, weight: .semibold))

                    Text("네트워크 연결이 없어 AI 응답은 제한됩니다.\n로컬 파일/문서 기능과 저장된 작업은 계속 사용할 수 있습니다.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.controlBorderColor), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var connectorLimitedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                    .frame(width: 20, alignment: .top)

                VStack(alignment: .leading, spacing: 6) {
                    Text("일부 기능 준비 중")
                        .font(.system(size: 13, weight: .semibold))

                    Text("Google Calendar 읽기 연결은 준비 중입니다.\n메일 발송이나 일정 생성은 자동 실행하지 않습니다.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.controlBorderColor), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 0) {
        FirstLaunchBannerView(
            state: FirstLaunchState(
                hasSeenOnboarding: false,
                hasAPIKey: false,
                capabilityMode: .localOnly
            )
        )
        Spacer()
    }
    .background(Color(.windowBackgroundColor))
}
