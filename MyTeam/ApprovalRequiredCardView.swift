import SwiftUI

// MARK: - ApprovalRequiredCardView
// Round 246B-ACTION: 승인 필요 작업을 채팅 흐름에서 보여주는 카드.
//
// 정책:
// - 246B에서 승인 버튼은 상태만 변경 (실제 재실행은 이후 라운드 연결)
// - destructive 위험 수준은 붉은 강조 가능
// - 차분한 확인 카드 스타일 (WorkResultCardView와 통일)
// - "승인 후 즉시 실행"이 아닌 "승인 대기 등록"

struct ApprovalRequiredCardView: View {
    let request: PendingApprovalRequest
    var onApprove: ((UUID) -> Void)?
    var onReject: ((UUID) -> Void)?
    var onDraftOnly: ((String) -> Void)?  // 초안만 보기 → directChat fallback

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: riskIcon)
                    .foregroundColor(riskColor)
                    .font(.system(size: 14, weight: .medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text("실행 전 확인이 필요합니다")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(request.toolName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(riskBadge)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.12))
                    .foregroundColor(riskColor)
                    .clipShape(Capsule())

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Divider()

                // Reason
                Text(request.reason)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Timestamp
                Text("요청 시각: \(request.createdAt.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))

                // Actions
                HStack(spacing: 8) {
                    // 초안만 보기 — 항상 동작 (246B)
                    if let onDraftOnly {
                        Button("초안만 보기") {
                            onDraftOnly(request.toolName)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // 취소
                    Button("취소") {
                        onReject?(request.id)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)

                    // 승인 대기 등록 (246B: 상태 변경만)
                    Button("승인 대기 등록") {
                        onApprove?(request.id)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(riskColor)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)

                // 246B notice
                Text("승인 후 실행 미리보기 연결은 다음 단계에서 진행됩니다.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(riskColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var riskIcon: String {
        switch request.riskLevel {
        case .destructive: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        default: return "checkmark.shield"
        }
    }

    private var riskColor: Color {
        switch request.riskLevel {
        case .destructive: return .red
        case .high: return .orange
        default: return .accentColor
        }
    }

    private var riskBadge: String {
        switch request.riskLevel {
        case .destructive: return "높은 위험"
        case .high: return "확인 필요"
        default: return "일반"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ApprovalRequiredCardView_Previews: PreviewProvider {
    static var previews: some View {
        ApprovalRequiredCardView(
            request: PendingApprovalRequest(
                id: UUID(),
                roomID: UUID(),
                toolName: "sendMail",
                input: ["to": "team@example.com"],
                riskLevel: .high,
                reason: "이 작업은 실행 전 확인이 필요합니다: sendMail",
                createdAt: Date(),
                expiresAt: nil,
                status: .pending
            ),
            onApprove: { _ in },
            onReject: { _ in },
            onDraftOnly: { _ in }
        )
        .frame(width: 320)
        .padding()
    }
}
#endif
