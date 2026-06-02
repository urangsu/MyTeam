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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: providerIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        stateBadge
                    }
                    Text(provider.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    executionModeBadges
                }

                Spacer()

                if let url = provider.keyIssueURL {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("API 키 발급 페이지를 엽니다")
                }
            }

            if health.state != .notConnected {
                HStack(spacing: 7) {
                    Text(healthService.health(for: provider).maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: runTest) {
                        if isTesting {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Label("확인", systemImage: "checkmark.circle")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTesting)

                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.7))
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
            }

            if let message = statusMessage {
                Label {
                    Text(message)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
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

                                SecureField(field.placeholder, text: Binding(
                                    get: { inputValues[field.id] ?? "" },
                                    set: { inputValues[field.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
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
                    } else {
                        Button {
                            isEditing = true
                        } label: {
                            Label("키 변경", systemImage: "key.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if health.state == .notConnected {
                        Text("키 없이도 로컬 기능은 사용할 수 있습니다.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
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
            return nil
        case .untested:
            return "키는 저장됐습니다. 실제 사용 가능 여부는 확인 버튼으로 검증하세요."
        case .testUnavailable:
            return "\(provider.displayName)은 자동 검증기가 아직 없습니다. 오늘 수동 API 테스트를 위해 키 저장과 삭제는 유지됩니다."
        case .testFailed(let code):
            return code.userMessage(for: provider)
        case .connected:
            return "실제 연결 확인을 통과했습니다."
        }
    }

    private var executionModeBadges: some View {
        HStack(spacing: 5) {
            Text("개인 키 연결 가능")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.10)))

            if provider.executionModes.contains(.proxyPlanned) {
                Text("기본 조회 준비 중")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.08)))
            }
        }
    }

    private var statusIcon: String {
        switch health.state {
        case .connected: return "checkmark.seal.fill"
        case .testFailed: return "exclamationmark.triangle.fill"
        case .testUnavailable: return "info.circle.fill"
        default: return "key.fill"
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
        Text(health.state.displayLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(badgeTextColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeBgColor))
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
            await CredentialHealthService.shared.testConnection(for: provider)
            let health = CredentialHealthService.shared.health(for: provider)
            await MainActor.run {
                isTesting = false
                switch health.state {
                case .connected:
                    testResultMessage = "연결 상태를 확인했습니다."
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
