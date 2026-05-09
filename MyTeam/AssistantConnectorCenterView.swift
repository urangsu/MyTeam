import SwiftUI

struct AssistantConnectorCenterView: View {
    @State private var refreshToken = UUID()

    private var connectors: [AssistantConnector] {
        AssistantConnectorCatalog.connectors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ForEach(connectors) { connector in
                connectorCard(for: connector)
            }

            scopePolicySection
        }
        .onAppear { refreshToken = UUID() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.blue)
                Text("비서 연결")
                    .font(.headline)
                Spacer()
                Button("상태 새로고침") {
                    refreshToken = UUID()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("일정과 메일을 읽어 오늘 브리핑을 만드는 기능을 준비 중입니다. macOS Desktop OAuth만 전제로 두고, Web Server OAuth / CLI / gcloud 의존성은 두지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connectorCard(for connector: AssistantConnector) -> some View {
        let state = AssistantConnectorCatalog.connectionState(for: connector.id)
        let connectorDecision = AssistantConnectorPolicy.decision(for: connector)
        let scopeBadges = connector.capabilities.reduce(into: [String]()) { badges, capability in
            let label = AssistantConnectorPolicy.decision(for: capability).badgeLabel
            if !badges.contains(label) {
                badges.append(label)
            }
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(connector.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.status.badgeLabel)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(badgeFillColor(for: state.status)))
                    }
                    Text(connector.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(state.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(connector.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(connectorDecision.badgeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Button("연결 준비 중") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(true)
                }
            }

            HStack(spacing: 6) {
                ForEach(scopeBadges, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(badgeBackgroundColor(for: label))
                        )
                }
                Spacer()
            }

            if connector.id == .googleCalendar || connector.id == .gmail {
                googleScopeRow(for: connector.id)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.14)))
        .id(refreshToken)
    }

    private func googleScopeRow(for provider: AssistantConnector.Provider) -> some View {
        let scopes: [GoogleOAuthScope]
        switch provider {
        case .googleCalendar:
            scopes = [.calendarEventsReadonly]
        case .gmail:
            scopes = [.gmailMetadata, .gmailReadonly]
        default:
            scopes = []
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(provider == .googleCalendar ? "Google Calendar OAuth scope" : "Gmail OAuth scope")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(scopes, id: \.self) { scope in
                    let decision = GoogleOAuthPolicy.decision(for: scope)
                    Text("\(scope.displayName) · \(decisionLabel(decision))")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(scopeBadgeColor(for: decision)))
                }
                Spacer()
            }
        }
    }

    private var scopePolicySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google OAuth 정책")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(GoogleOAuthScope.allCases.sorted(by: { $0.priority < $1.priority }), id: \.self) { scope in
                let decision = GoogleOAuthPolicy.decision(for: scope)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scope.displayName)
                            .font(.caption)
                        Text(scope.policySummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(decisionLabel(decision))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(scopeBadgeColor(for: decision)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.25)))
    }

    private func decisionLabel(_ decision: GoogleOAuthPolicyDecision) -> String {
        switch decision {
        case .autoAllowed: return "읽기 가능 예정"
        case .requiresApproval: return "승인 필요"
        case .blocked: return "자동 실행 차단"
        }
    }

    private func scopeBadgeColor(for decision: GoogleOAuthPolicyDecision) -> Color {
        switch decision {
        case .autoAllowed: return Color.green.opacity(0.12)
        case .requiresApproval: return Color.orange.opacity(0.14)
        case .blocked: return Color.red.opacity(0.14)
        }
    }

    private func badgeBackgroundColor(for label: String) -> Color {
        if label.contains("자동 실행 차단") { return Color.red.opacity(0.10) }
        if label.contains("승인 필요") { return Color.orange.opacity(0.12) }
        return Color.green.opacity(0.10)
    }

    private func badgeFillColor(for status: GoogleOAuthConnectionState.Status) -> Color {
        switch status {
        case .notConfigured: return Color.gray.opacity(0.12)
        case .notConnected: return Color.orange.opacity(0.12)
        case .comingSoon: return Color.blue.opacity(0.12)
        case .connected: return Color.green.opacity(0.12)
        case .needsReauth: return Color.yellow.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        }
    }
}
