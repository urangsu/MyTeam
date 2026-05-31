import SwiftUI

// MARK: - ConnectorFailureCardView

/// 외부 API / 커넥터 실패 시 사용자에게 보여주는 복구 카드.
/// 빨간 alert 대신 차분한 주의 tone으로 표시하고 복구 액션을 제안합니다.
struct ConnectorFailureCardView: View {
    let failureCode: ConnectorFailureCode
    let provider: ExternalProvider?
    var onConnectKey: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(toneColor)

                Text(provider?.displayName ?? "연결 오류")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if let dismiss = onDismiss {
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 사용자 메시지
            Text(failureCode.userMessage(for: provider))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 복구 액션 버튼들
            let hints = failureCode.recoveryHints
            if !hints.isEmpty {
                HStack(spacing: 8) {
                    ForEach(hints.indices, id: \.self) { idx in
                        recoveryButton(for: hints[idx])
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toneColor.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toneColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Recovery Button

    @ViewBuilder
    private func recoveryButton(for hint: ConnectorFailureCode.RecoveryHint) -> some View {
        switch hint {
        case .connectKey:
            Button("키 연결하기") {
                onConnectKey?()
            }
            .buttonStyle(FailureRecoveryButtonStyle(isPrimary: true))

        case .reEnterKey:
            Button("다시 입력하기") {
                onConnectKey?()
            }
            .buttonStyle(FailureRecoveryButtonStyle(isPrimary: true))

        case .openKeyGuide:
            if let url = provider?.keyIssueURL {
                Button("발급 안내 보기") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(FailureRecoveryButtonStyle(isPrimary: false))
            }

        case .openProviderSite:
            if let url = provider?.keyIssueURL {
                Button("\(provider?.displayName ?? "서비스") 열기") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(FailureRecoveryButtonStyle(isPrimary: false))
            }

        case .retryLater:
            Button("나중에") {
                onDismiss?()
            }
            .buttonStyle(FailureRecoveryButtonStyle(isPrimary: false))

        case .checkNetwork:
            Button("네트워크 확인") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUI") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(FailureRecoveryButtonStyle(isPrimary: false))
        }
    }

    // MARK: - Tone

    private var toneColor: Color {
        switch failureCode {
        case .missingAPIKey, .invalidAPIKey, .permissionDenied:
            return .orange
        case .quotaExceeded, .rateLimited:
            return .yellow
        case .providerUnavailable, .networkError, .responseParseFailed:
            return .secondary
        case .unsupportedRegion, .releaseProfileBlocked:
            return .secondary
        }
    }

    private var iconName: String {
        switch failureCode {
        case .missingAPIKey:          return "key.slash"
        case .invalidAPIKey:          return "key.slash"
        case .permissionDenied:       return "lock.slash"
        case .quotaExceeded:          return "gauge.with.dots.needle.33percent"
        case .rateLimited:            return "clock.badge.exclamationmark"
        case .providerUnavailable:    return "wifi.exclamationmark"
        case .networkError:           return "wifi.slash"
        case .responseParseFailed:    return "exclamationmark.circle"
        case .unsupportedRegion:      return "globe.badge.chevron.backward"
        case .releaseProfileBlocked:  return "lock.shield"
        }
    }
}

// MARK: - FailureRecoveryButtonStyle

private struct FailureRecoveryButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: isPrimary ? .semibold : .regular))
            .foregroundStyle(isPrimary ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPrimary
                          ? Color.accentColor.opacity(0.12)
                          : Color.secondary.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Preview Helper

#if DEBUG
struct ConnectorFailureCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ConnectorFailureCardView(
                failureCode: .missingAPIKey,
                provider: .kmaWeather,
                onConnectKey: {},
                onDismiss: {}
            )
            ConnectorFailureCardView(
                failureCode: .invalidAPIKey,
                provider: .gemini,
                onConnectKey: {},
                onDismiss: {}
            )
            ConnectorFailureCardView(
                failureCode: .networkError,
                provider: nil,
                onConnectKey: nil,
                onDismiss: {}
            )
        }
        .padding()
        .frame(width: 360)
    }
}
#endif
