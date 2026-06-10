import Foundation

struct ToolApprovalRequest: Identifiable, Sendable, Equatable {
    let id = UUID()
    let descriptor: MyTeamToolDescriptor
    let reason: String
    let query: String

    var title: String {
        "\(descriptor.displayName) 실행 승인"
    }

    var permissionLevel: MyTeamPermissionLevel {
        descriptor.permissionLevel
    }

    var strongConfirmationText: String? {
        switch descriptor.permissionLevel {
        case .destructiveRequiresApproval:
            return "삭제"
        case .externalSendRequiresApproval:
            return "전송"
        case .readOnly, .draftOnly, .writeRequiresApproval:
            return nil
        }
    }
}
