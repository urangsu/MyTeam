import SwiftUI
import AppKit

// MARK: - ConnectorSetupCardView

/// 단일 외부 provider 연결 카드.
/// - 이 연결로 무엇을 할 수 있는지
/// - 현재 상태 badge
/// - 키 붙여넣기 / 테스트 / 삭제 액션
struct ConnectorSetupCardView: View {
    let provider: ExternalProvider

    @StateObject private var healthService = CredentialHealthService.shared
    @State private var inputValues: [String: String] = [:]
    @State private var isEditing: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResultMessage: String? = nil
    @State private var showDeleteConfirm: Bool = false

    private var health: CredentialHealth {
        healthService.health(for: provider)
    }

    private var schema: ProviderCredentialSchema {
        provider.credentialSchema
    }

    private var canSaveInput: Bool {
        schema.fields.allSatisfy { field in
            !(inputValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: providerIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        stateBadge
                        if health.state != .notConnected && !health.state.isConnected {
                            storedBadge
                        }
                    }
                }
                .help(provider.description)

                Spacer()

                if let url = provider.keyIssueURL {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("API 키 발급 페이지를 엽니다")
                    .frame(width: 28, height: 24, alignment: .trailing)
                } else {
                    Color.clear
                        .frame(width: 28, height: 24)
                }
            }

            if health.state != .notConnected {
                HStack(spacing: 7) {
                    Text(healthService.health(for: provider).maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 6) {
                        Button {
                            isEditing = true
                        } label: {
                            Label("키 변경", systemImage: "key.fill")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: runTest) {
                            if isTesting {
                                ProgressView().scaleEffect(0.6)
                                    .frame(width: 42, height: 18)
                            } else {
                                Label("검증", systemImage: validationButtonIcon)
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTesting)

                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("삭제", systemImage: "trash")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red.opacity(0.8))
                        .help("API 키 삭제")
                        .confirmationDialog(
                            "\(provider.displayName) 키를 삭제할까요?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("삭제", role: .destructive) { deleteKey() }
                            Button("취소", role: .cancel) {}
                        }
                    }
                    .frame(width: 210, height: 28, alignment: .trailing)
                }
                .frame(minHeight: 30)
            }

            if let message = statusMessage {
                Label {
                    Text(message)
                        .font(.system(size: 11))
                        .lineLimit(2)
                } icon: {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(statusColor)
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(schema.fields) { field in
                            HStack(spacing: 8) {
                                Text(field.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(width: 92, alignment: .leading)

                                credentialInput(for: field)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button("저장") { saveKey() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!canSaveInput)
                        if isEditing {
                            Button("취소") {
                                inputValues = [:]
                                isEditing = false
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Text("키는 이 기기 안에 안전하게 저장됩니다. MyTeam 서버로 전송되지 않습니다.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    if health.state == .notConnected {
                        Button {
                            isEditing = true
                        } label: {
                            Label("키 입력", systemImage: "key.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .frame(minHeight: 30)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    borderColor,
                    lineWidth: 1
                )
        )
    }

    private var providerIcon: String {
        switch provider {
        case .openAI, .gemini, .anthropic, .openRouter:
            return "sparkles"
        case .kmaWeather:
            return "cloud.sun.fill"
        case .naverNews:
            return "newspaper.fill"
        case .dartDisclosure:
            return "chart.line.uptrend.xyaxis"
        case .koreanLaw:
            return "building.columns.fill"
        case .publicDataPortal:
            return "tablecells.fill"
        }
    }

    private var iconColor: Color {
        switch health.state {
        case .connected: return .green
        case .testFailed: return .orange
        case .untested, .testUnavailable: return .blue
        case .notConnected: return .secondary
        }
    }

    private var statusMessage: String? {
        if let testResultMessage { return testResultMessage }
        switch health.state {
        case .notConnected:
            if provider == .dartDisclosure {
                return "DART 공시 조회에는 개인 OpenDART API Key 연결이 필요합니다. 키는 이 기기의 Keychain에 저장됩니다."
            }
            if provider.isPublicAPIProvider {
                return "기본 조회를 먼저 사용합니다. 개인 키 연결은 장애 대응과 고급 사용을 위한 선택 사항입니다."
            }
            return nil
        case .untested:
            return provider.hasLiveCredentialValidator
                ? "저장됨. 검증을 누르면 실제 연결 여부를 확인합니다."
                : "저장됨. 자동 검증은 준비 중입니다."
        case .testUnavailable:
            return "저장됨. 자동 검증은 준비 중입니다."
        case .testFailed(let code):
            return code.userMessage(for: provider)
        case .connected:
            return nil
        }
    }

    private var validationButtonIcon: String {
        provider.hasLiveCredentialValidator ? "checkmark.circle" : "key.viewfinder"
    }

    private var statusIcon: String {
        switch health.state {
        case .connected: return "checkmark.seal.fill"
        case .testFailed: return "exclamationmark.triangle.fill"
        case .testUnavailable: return "info.circle.fill"
        default: return "key.fill"
        }
    }

    @ViewBuilder
    private func credentialInput(for field: CredentialField) -> some View {
        let binding = Binding(
            get: { inputValues[field.id] ?? "" },
            set: { inputValues[field.id] = $0 }
        )
        if field.isSecret {
            SecureField(field.placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        } else {
            TextField(field.placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private var statusColor: Color {
        switch health.state {
        case .connected: return .green
        case .testFailed: return .orange
        case .testUnavailable, .untested: return .secondary
        case .notConnected: return .secondary
        }
    }

    // MARK: - State Badge

    private var stateBadge: some View {
        Text(stateBadgeLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(badgeTextColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeBgColor))
            .frame(minWidth: 62, alignment: .leading)
    }

    private var stateBadgeLabel: String {
        switch health.state {
        case .connected: return "사용 가능"
        case .notConnected: return "미연결"
        case .untested: return "미검증"
        case .testUnavailable: return "검증 준비 중"
        case .testFailed: return "확인 필요"
        }
    }

    private var storedBadge: some View {
        Text("저장됨")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.10)))
            .frame(minWidth: 54, alignment: .leading)
    }

    private var badgeBgColor: Color {
        switch health.state {
        case .connected:      return Color.green.opacity(0.15)
        case .notConnected:   return Color.secondary.opacity(0.12)
        case .untested:       return Color.blue.opacity(0.12)
        case .testUnavailable:return Color.blue.opacity(0.12)
        case .testFailed:     return Color.orange.opacity(0.15)
        }
    }

    private var badgeTextColor: Color {
        switch health.state {
        case .connected:      return .green
        case .notConnected:   return .secondary
        case .untested:       return .blue
        case .testUnavailable:return .blue
        case .testFailed:     return .orange
        }
    }

    private var borderColor: Color {
        switch health.state {
        case .connected:      return Color.green.opacity(0.25)
        case .untested,
             .testUnavailable:return Color.blue.opacity(0.20)
        case .testFailed:     return Color.orange.opacity(0.25)
        default:              return Color.black.opacity(0.06)
        }
    }

    // MARK: - Actions

    private func saveKey() {
        guard canSaveInput else { return }
        if schema.fields.count == 1, let field = schema.fields.first {
            let value = inputValues[field.id] ?? ""
            SecureCredentialStore.shared.save(provider: provider, key: value)
        }
        for field in schema.fields {
            let value = inputValues[field.id] ?? ""
            SecureCredentialStore.shared.save(provider: provider, field: field, value: value)
        }
        CredentialHealthService.shared.didSaveKey(for: provider)
        inputValues = [:]
        isEditing = false
        testResultMessage = nil
    }

    private func deleteKey() {
        for field in schema.fields {
            SecureCredentialStore.shared.delete(provider: provider, field: field)
        }
        SecureCredentialStore.shared.delete(provider: provider)
        CredentialHealthService.shared.didDeleteKey(for: provider)
        testResultMessage = nil
    }

    private func runTest() {
        isTesting = true
        testResultMessage = nil
        Task {
            await CredentialHealthService.shared.testConnection(for: provider, force: true)
            let health = CredentialHealthService.shared.health(for: provider)
            await MainActor.run {
                isTesting = false
                switch health.state {
                case .connected:
                    if let readiness = health.llmReadiness {
                        testResultMessage = "\(readiness.modelID) 모델의 실제 응답을 확인했습니다."
                    } else {
                        testResultMessage = "실제 API 응답을 확인했습니다."
                    }
                case .testUnavailable:
                    testResultMessage = "\(provider.displayName) 실제 연결 테스트는 아직 준비 중입니다. 키는 저장됐지만 연결됨으로 표시하지 않습니다."
                case .testFailed(let code):
                    testResultMessage = code.userMessage(for: provider)
                default:
                    testResultMessage = "키가 저장되어 있습니다. 실제 연결 테스트는 준비 중이에요."
                }
            }
        }
    }
}
