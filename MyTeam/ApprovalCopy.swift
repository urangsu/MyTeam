import Foundation

// MARK: - ApprovalCopy
// Round 278 2-B: 승인/차단/대기 메시지를 한 곳에서 관리.
// CapabilityAwareRouter, ApprovalPolicy, CapabilityFallbackService, ApprovalRequiredCardView가
// 모두 이 파일을 참조하도록 점진 통합.
//
// 책임 분담 원칙:
// - ApprovalPolicy → 사용자 데이터 변경(write/delete/send) 승인 판정 전담
// - CapabilityAwareRouter → 미구현/coming soon 기능 판정 전담
// - ApprovalCopy → 두 영역에서 보여줄 문구 전담

enum ApprovalCopy {

    // MARK: - 승인 필요 (외부 쓰기 / 도구 실행)
    static let approvalNeededExternalWrite = "외부 전송은 실행 전 확인이 필요해요. 내용을 확인하시고 진행해 주세요."
    static let approvalNeededToolExecution = "이 작업은 실행 전 한 번 확인이 필요해요."

    // MARK: - 안전 정책상 차단 (변경 불가)
    static let blockedSafetyPolicy = "이 작업은 안전 정책상 자동으로 실행하지 않아요. 필요하시면 직접 수동으로 진행해 주세요."

    // MARK: - 미구현 / 준비 중
    static let plannedFeature = "이 기능은 준비 중이에요. 가능한 다른 방법으로 도와드릴게요."
    static let comingSoonFeature = "이 기능은 곧 출시 예정이에요. 지금은 직접 진행해 주세요."

    // MARK: - 자동 허용
    static let autoAllowed = "현재 앱 기능으로 바로 처리할 수 있어요."

    // MARK: - Helper: ApprovalDecision → 메시지
    /// 같은 결정을 어떤 코드 경로에서 표시하든 동일한 문구로 통일.
    static func message(for decision: ApprovalDecision) -> String {
        switch decision {
        case .autoAllowed:
            return autoAllowed
        case .requiresApproval(let reason):
            // 백엔드 reason이 있으면 활용, 없으면 디폴트
            return reason.isEmpty ? approvalNeededToolExecution : reason
        case .blocked(let reason):
            return reason.isEmpty ? blockedSafetyPolicy : reason
        }
    }

    // MARK: - Helper: CapabilityRouteDecision.Status → 메시지
    /// CapabilityAwareRouter가 반환하는 상태별 사용자 문구.
    static func message(for status: CapabilityRouteDecision.Status) -> String {
        switch status {
        case .available:        return autoAllowed
        case .requiresApproval: return approvalNeededToolExecution
        case .blocked:          return blockedSafetyPolicy
        case .future:           return plannedFeature
        case .unavailable:      return "이 기능은 아직 사용할 수 없어요. 지금은 로컬 파일·문서 기능을 활용하실 수 있어요."
        }
    }
}
