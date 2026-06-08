import Foundation

struct PermissionDecision: Sendable, Equatable {
    let canRunAutomatically: Bool
    let requiresApproval: Bool
    let requiresStrongConfirmation: Bool
    let userFacingReason: String
}

enum ToolPermissionPolicy {
    nonisolated static func decision(for level: MyTeamPermissionLevel) -> PermissionDecision {
        switch level {
        case .readOnly:
            return PermissionDecision(
                canRunAutomatically: true,
                requiresApproval: false,
                requiresStrongConfirmation: false,
                userFacingReason: "읽기 작업이라 바로 실행할 수 있습니다."
            )
        case .draftOnly:
            return PermissionDecision(
                canRunAutomatically: true,
                requiresApproval: false,
                requiresStrongConfirmation: false,
                userFacingReason: "초안만 만들기 때문에 바로 실행할 수 있습니다."
            )
        case .writeRequiresApproval:
            return PermissionDecision(
                canRunAutomatically: false,
                requiresApproval: true,
                requiresStrongConfirmation: false,
                userFacingReason: "저장 또는 변경 전 승인이 필요합니다."
            )
        case .destructiveRequiresApproval:
            return PermissionDecision(
                canRunAutomatically: false,
                requiresApproval: true,
                requiresStrongConfirmation: true,
                userFacingReason: "삭제 작업은 강한 확인이 필요합니다."
            )
        case .externalSendRequiresApproval:
            return PermissionDecision(
                canRunAutomatically: false,
                requiresApproval: true,
                requiresStrongConfirmation: true,
                userFacingReason: "외부 전송 전 강한 확인이 필요합니다."
            )
        }
    }
}
