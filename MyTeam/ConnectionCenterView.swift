import SwiftUI

enum ConnectionCenterUserCopy {
    static let storageLocation = "이 Mac"
    static let storageExplanation = "키는 이 Mac에 안전하게 저장됩니다. 저장만으로 연결 성공을 표시하지 않고, 실제 확인이 된 경우에만 사용 가능으로 표시합니다."
}

// MARK: - ConnectionCenterView

/// 연결 센터 — 외부 서비스를 연결하는 메인 허브.
/// 개발자 설정처럼 보이지 않고, 카드형 연결 가이드로 구성됩니다.
struct ConnectionCenterView: View {
    let focusedProvider: ExternalProvider?

    @StateObject private var healthService = CredentialHealthService.shared
    @AppStorage("MyTeam.LLMFallbackPolicy") private var fallbackPolicyRaw = LLMFallbackPolicy.disabled.rawValue

    private let aiProviders: [ExternalProvider] = [.gemini, .openAI, .anthropic, .openRouter]
    private let dataProviders: [ExternalProvider] = [.kmaWeather, .naverNews, .dartDisclosure, .koreanLaw, .publicDataPortal]

    private var connectedAIProviderCount: Int {
        aiProviders.filter { healthService.health(for: $0).state.isConnected }.count
    }

    private var storedAIProviderCount: Int {
        aiProviders.filter { healthService.health(for: $0).state != .notConnected }.count
    }

    private var focusedProviderSection: some View {
        Group {
            if let focusedProvider {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(
                        icon: "target",
                        title: "\(focusedProvider.displayName) 연결",
                        subtitle: "방금 선택한 업무에 필요한 연결입니다."
                    )
                    ConnectorSetupCardView(provider: focusedProvider)
                }
            }
        }
    }

    private var visibleAIProviders: [ExternalProvider] {
        aiProviders.filter { $0 != focusedProvider }
    }

    private var visibleDataProviders: [ExternalProvider] {
        dataProviders.filter { $0 != focusedProvider }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            focusedProviderSection

            providerSection(
                icon: "sparkles",
                title: "AI 모델",
                subtitle: "대화, 문서 작성, 분석에 사용합니다. 하나만 검증돼도 MyTeam을 사용할 수 있습니다.",
                providers: visibleAIProviders
            )

            routingSection

            fallbackPolicySection

            providerSection(
                icon: "building.columns.fill",
                title: "데이터 연결",
                subtitle: "뉴스, 날씨, 공시, 법령은 기본 조회를 먼저 사용합니다. 개인 키는 장애 대응과 고급 사용을 위한 선택 사항입니다.",
                providers: visibleDataProviders
            )

            requirementNoticeView
        }
        .padding(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("연결")
                    .font(.system(size: 19, weight: .bold))
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
                summaryTile(title: "저장 위치", value: ConnectionCenterUserCopy.storageLocation, icon: "lock.fill")
            }

            Text(ConnectionCenterUserCopy.storageExplanation)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                icon: "arrow.triangle.branch",
                title: "데스크별 사용 경로",
                subtitle: "각 데스크가 사용할 AI를 고릅니다. 키 저장과 실제 연결 성공은 별도로 표시됩니다."
            )

            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    DeskRoutingPreferenceRow(deskIndex: index, healthService: healthService)
                }
            }
        }
    }

    private var fallbackPolicySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                icon: "arrow.triangle.swap",
                title: "응답 실패 시 처리",
                subtitle: "다른 AI로 요청을 보낼지 사용자가 직접 결정합니다. 기본값은 사용 안 함입니다."
            )

            Picker("응답 실패 시 처리", selection: $fallbackPolicyRaw) {
                ForEach(LLMFallbackPolicy.allCases, id: \.rawValue) { policy in
                    Text(policy.displayName).tag(policy.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedFallbackPolicy.userFacingDescription)
                .font(.system(size: 10))
                .foregroundStyle(selectedFallbackPolicy == .crossProviderAllowed ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectedFallbackPolicy: LLMFallbackPolicy {
        LLMFallbackPolicy(rawValue: fallbackPolicyRaw) ?? .disabled
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
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 42)
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

private struct DeskRoutingPreferenceRow: View {
    let deskIndex: Int
    @ObservedObject var healthService: CredentialHealthService

    @AppStorage private var providerRaw: String
    @AppStorage private var modelId: String

    init(deskIndex: Int, healthService: CredentialHealthService) {
        self.deskIndex = deskIndex
        self.healthService = healthService
        _providerRaw = AppStorage(
            wrappedValue: LLMProvider.gemini.rawValue,
            "llmProvider_desk_\(deskIndex)"
        )
        _modelId = AppStorage(
            wrappedValue: "",
            "openRouterModelId_desk_\(deskIndex)"
        )
    }

    private var selectedProvider: LLMProvider {
        LLMProvider(rawValue: providerRaw) ?? .gemini
    }

    private var externalProvider: ExternalProvider {
        switch selectedProvider {
        case .gemini:
            return .gemini
        case .openAI:
            return .openAI
        case .claude:
            return .anthropic
        case .openRouter:
            return .openRouter
        }
    }

    private var health: CredentialHealth {
        healthService.health(for: externalProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("데스크 \(deskIndex + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 54, alignment: .leading)

                Picker("AI", selection: $providerRaw) {
                    ForEach(LLMProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 150)

                stateBadge

                Spacer(minLength: 0)
            }

            if selectedProvider == .openRouter {
                if AIModelPolicy.modelOverrideAllowed {
                    HStack(spacing: 8) {
                        Text("모델")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .leading)
                        TextField("자동", text: $modelId)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Text("Release에서는 검증된 모델 정책을 사용합니다.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var stateBadge: some View {
        Text(health.state.displayLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeColor.opacity(0.12)))
            .help(health.maskedKey)
    }

    private var badgeColor: Color {
        switch health.state {
        case .connected:
            return .green
        case .notConnected:
            return .secondary
        case .untested, .testUnavailable:
            return .orange
        case .testFailed:
            return .red
        }
    }
}
