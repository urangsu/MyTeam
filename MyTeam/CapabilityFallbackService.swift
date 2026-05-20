import Foundation

// MARK: - FallbackAction
// Round 246A-HOTFIX: capability/feature 차단 시 WorkflowOrchestrator가 선택할 대응 행동.
//
// 레이어 규칙:
// - ToolExecutionLayer → typed ToolResultStatus만 반환
// - WorkflowOrchestrator → CapabilityFallbackService.fallbackAction() 호출 후 pivot 결정
// - LLM/UI 호출은 WorkflowOrchestrator 책임

enum FallbackAction {
    case directChat(message: String)           // LLM에게 메시지 그대로 전달
    case draftOnly(prompt: String)             // 초안 작성 전용 프롬프트로 LLM 호출
    case askForFile(message: String)           // "자료를 올려주세요" 안내
    case askForConfirmation(PendingApprovalRequest) // 승인 요청 배너 표시 (246B 구현)
    case plannedNotice(message: String)        // "준비 중" 안내 후 directChat
    case hardBlock(message: String)            // 실행 불가 (payment/login/delete)
}

// MARK: - CapabilityFallbackService

enum CapabilityFallbackService {

    /// FeatureAvailability → FallbackAction 변환
    /// WorkflowOrchestrator가 .planned/.unavailable/.approvalRequired ToolResultStatus를
    /// 받은 뒤 이 함수로 사용자 경험을 결정한다.
    static func fallbackAction(
        availability: FeatureAvailability,
        userMessage: String,
        skillID: String? = nil
    ) -> FallbackAction {
        switch availability {
        case .available:
            return .directChat(message: userMessage)

        case .assistOnly:
            let notice = skillID.flatMap { SkillAvailabilityResolver.assistOnlyMessage(for: $0) }
                ?? "직접 실행은 아직 연결 전입니다. 자료를 주시면 정리·초안·검토 형태로 도와드릴게요."
            return .directChat(message: notice)

        case .draftOnly:
            return .draftOnly(prompt: userMessage)

        case .approvalBound:
            // 246B에서 실제 PendingApprovalRequest 생성 + 승인 UI 연결
            return .plannedNotice(message: "이 작업은 승인 후 실행할 수 있습니다. 관련 초안을 먼저 작성해드릴게요.")

        case .planned:
            return .plannedNotice(message: "아직 준비 중인 기능입니다. 가능한 방법으로 대신 도와드릴게요.")

        case .hidden:
            return .plannedNotice(message: "아직 공개되지 않은 기능입니다.")

        case .blocked:
            return .hardBlock(message: "이 작업은 안전 정책상 실행할 수 없습니다.")
        }
    }

    /// ToolResultStatus → FallbackAction 변환
    /// ToolExecutionLayer가 typed result를 반환한 뒤 Orchestrator가 이 함수로 행동을 결정한다.
    static func fallbackAction(
        toolResultStatus: ToolResultStatus,
        toolName: String,
        error: String?,
        userMessage: String
    ) -> FallbackAction {
        switch toolResultStatus {
        case .succeeded, .dryRun, .cancelled:
            return .directChat(message: userMessage)

        case .planned:
            return .plannedNotice(message: error ?? "아직 준비 중인 도구입니다. 다른 방법으로 도와드릴게요.")

        case .unavailable:
            return .plannedNotice(message: error ?? "현재 사용할 수 없는 도구입니다.")

        case .approvalRequired:
            // 246B: 실제 PendingApprovalRequest 생성
            return .plannedNotice(message: error ?? "이 작업은 승인 후 실행할 수 있습니다.")

        case .failed:
            return .directChat(message: "도구 실행 중 문제가 발생했습니다. 다른 방법으로 시도해드릴게요.")

        case .blocked:
            return .hardBlock(message: error ?? "이 작업은 안전 정책상 실행할 수 없습니다.")
        }
    }
}
