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
    @State private var inputKey: String = ""
    @State private var isEditing: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResultMessage: String? = nil
    @State private var showDeleteConfirm: Bool = false

    private var health: CredentialHealth {
        healthService.health(for: provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더 행
            HStack(alignment: .top, spacing: 10) {
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
                }

                Spacer()

                // 키 발급 바로가기
                if let url = provider.keyIssueURL {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                            Text("발급")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("API 키 발급 페이지를 엽니다")
                }
            }

            // 연결된 경우 — 마스킹 표시 + 삭제
            if health.state != .notConnected {
                HStack(spacing: 8) {
                    Text(healthService.health(for: provider).maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 테스트
                    Button(action: runTest) {
                        if isTesting {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Text("연결 테스트")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTesting)

                    // 삭제
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

            // 테스트 결과 메시지
            if let msg = testResultMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(
                        health.state == .connected ? Color.green : Color.orange
                    )
            }

            // 키 입력 필드 (편집 모드 또는 미연결 상태)
            if isEditing || health.state == .notConnected {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        SecureField("API 키 붙여넣기", text: $inputKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))

                        Button("저장") { saveKey() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if isEditing {
                            Button("취소") {
                                inputKey = ""
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
            } else if health.state != .notConnected && !isEditing {
                Button("키 변경") { isEditing = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    borderColor,
                    lineWidth: 1
                )
        )
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
        case .testUnavailable:return Color.blue.opacity(0.22)
        case .testFailed:     return Color.orange.opacity(0.25)
        default:              return Color.black.opacity(0.06)
        }
    }

    // MARK: - Actions

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SecureCredentialStore.shared.save(provider: provider, key: trimmed)
        CredentialHealthService.shared.didSaveKey(for: provider)
        inputKey = ""
        isEditing = false
        testResultMessage = nil
    }

    private func deleteKey() {
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
