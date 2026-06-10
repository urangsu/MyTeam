import SwiftUI

struct ToolApprovalSheetView: View {
    let request: ToolApprovalRequest
    let onCancel: () -> Void
    let onApprove: () -> Void

    @State private var confirmationText = ""

    private var canApprove: Bool {
        guard let required = request.strongConfirmationText else { return true }
        return confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == required
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(tint)
                Text(request.title)
                    .font(.headline)
                Spacer()
            }

            Text(request.reason)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("권한")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(permissionText)
                    .font(.system(size: 12))
            }

            if let required = request.strongConfirmationText {
                VStack(alignment: .leading, spacing: 6) {
                    Text("확인 문구")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField(required, text: $confirmationText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Spacer()
                Button("취소", action: onCancel)
                    .buttonStyle(.bordered)
                Button("승인하고 실행", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApprove)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private var iconName: String {
        switch request.permissionLevel {
        case .destructiveRequiresApproval, .externalSendRequiresApproval:
            return "exclamationmark.triangle.fill"
        default:
            return "checkmark.shield.fill"
        }
    }

    private var tint: Color {
        switch request.permissionLevel {
        case .destructiveRequiresApproval, .externalSendRequiresApproval:
            return .orange
        default:
            return .blue
        }
    }

    private var permissionText: String {
        switch request.permissionLevel {
        case .readOnly:
            return "읽기 작업"
        case .draftOnly:
            return "초안 생성"
        case .writeRequiresApproval:
            return "저장 또는 변경 전 승인 필요"
        case .destructiveRequiresApproval:
            return "삭제 전 강한 확인 필요"
        case .externalSendRequiresApproval:
            return "외부 전송 전 강한 확인 필요"
        }
    }
}
