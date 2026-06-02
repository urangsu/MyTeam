import SwiftUI

// MARK: - ConnectionCenterView

/// 연결 센터 — 외부 서비스를 연결하는 메인 허브.
/// 개발자 설정처럼 보이지 않고, 카드형 연결 가이드로 구성됩니다.
struct ConnectionCenterView: View {
    private let profile = AppReleaseProfile.current
    @StateObject private var healthService = CredentialHealthService.shared

    private let aiProviders: [ExternalProvider] = [.gemini, .openAI, .anthropic, .openRouter]
    private let dataProviders: [ExternalProvider] = [.kmaWeather, .naverNews, .dartDisclosure]

    private var connectedAIProviderCount: Int {
        aiProviders.filter { healthService.health(for: $0).state.isConnected }.count
    }

    private var storedAIProviderCount: Int {
        aiProviders.filter { healthService.health(for: $0).state != .notConnected }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                providerSection(
                    icon: "sparkles",
                    title: "AI 모델",
                    subtitle: "대화, 문서 작성, 분석에 사용합니다. 하나만 검증돼도 MyTeam을 사용할 수 있습니다.",
                    providers: aiProviders
                )

                DisclosureGroup {
                    VStack(spacing: 8) {
                        ForEach(dataProviders, id: \.rawValue) { provider in
                            ConnectorSetupCardView(provider: provider)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    sectionHeader(
                        icon: "building.columns.fill",
                        title: "추가 데이터 연결",
                        subtitle: "날씨, 뉴스, 공시는 키 저장 후 수동 API 확인이 가능합니다."
                    )
                }

                if profile.policy.allowsExperimentalConnectors {
                    DisclosureGroup {
                        PlaywrightMCPSetupCardView()
                            .padding(.top, 8)
                    } label: {
                        sectionHeader(
                            icon: "wrench.and.screwdriver",
                            title: "개발자 연결",
                            subtitle: "브라우저 자동화 진단용입니다. Release/App Store 표면에서는 숨겨집니다."
                        )
                    }
                }

                requirementNoticeView

                Spacer(minLength: 20)
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("연결")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(connectedAIProviderCount > 0 ? "AI 사용 가능" : "로컬 기능 사용 가능")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(connectedAIProviderCount > 0 ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill((connectedAIProviderCount > 0 ? Color.green : Color.secondary).opacity(0.12))
                    )
            }

            HStack(spacing: 8) {
                summaryTile(title: "검증된 AI", value: "\(connectedAIProviderCount)", icon: "checkmark.seal.fill")
                summaryTile(title: "저장된 키", value: "\(storedAIProviderCount)", icon: "key.fill")
                summaryTile(title: "저장 위치", value: "Keychain", icon: "lock.fill")
            }

            Text("키는 이 Mac의 Keychain에 저장됩니다. 저장만으로 연결 성공을 표시하지 않고, 실제 확인이 된 경우에만 사용 가능으로 표시합니다.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryTile(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func providerSection(icon: String, title: String, subtitle: String, providers: [ExternalProvider]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: icon, title: title, subtitle: subtitle)
            VStack(spacing: 8) {
                ForEach(providers, id: \.rawValue) { provider in
                    ConnectorSetupCardView(provider: provider)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Requirement Notice

    private var requirementNoticeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("외부 서비스 안내", systemImage: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("연결한 서비스의 정책은 해당 서비스 기준을 따릅니다. MyTeam은 키를 서버에 보관하지 않으며, 키는 언제든 삭제할 수 있습니다.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

// MARK: - PlaywrightMCPSetupCardView

/// Playwright MCP 연결 카드. App Store profile에서는 숨겨집니다.
private struct PlaywrightMCPSetupCardView: View {
    @StateObject private var mcpManager = PlaywrightMCPManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Playwright MCP")
                            .font(.system(size: 13, weight: .semibold))
                        statusBadge
                    }
                    Text("웹 브라우저 자동화 기능입니다. Node.js와 npx가 필요합니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(action: {
                Task { await MainActor.run { PlaywrightMCPManager.shared.refreshHealth() } }
            }) {
                if mcpManager.isRefreshing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("확인 중...")
                            .font(.system(size: 11))
                    }
                } else {
                    Text("상태 확인")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(mcpManager.isRefreshing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            if mcpManager.health.initialized { return ("활성", .green) }
            if mcpManager.health.mcpLaunchable { return ("대기", .blue) }
            return ("미설치", .secondary)
        }()
        return Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}
