import Foundation

enum ClarificationDecision: Equatable {
    case proceedWithAssumptions([String])
    case askRequired([String])
    case blocked(String)
}

enum ClarificationPolicy {
    static func decide(for goal: GoalInterpretation) -> ClarificationDecision {
        let routeDecision = CapabilityAwareRouter.evaluate(goal: goal)
        switch routeDecision.status {
        case .blocked:
            return .blocked(routeDecision.message)
        case .requiresApproval:
            return .proceedWithAssumptions([
                "필요한 부분은 초안 기준으로 진행합니다.",
                "민감한 작업은 별도 확인이 필요합니다."
            ])
        case .future:
            return .proceedWithAssumptions([
                "현재는 연결 준비 단계입니다.",
                "연결 후 실제 데이터를 반영할 수 있습니다."
            ])
        case .available, .unavailable:
            break
        }

        if !goal.missingInputs.isEmpty {
            switch goal.goalType {
            case .appLaunch, .privacyTerms, .connectorSetup:
                return .askRequired(goal.missingInputs)
            default:
                return .proceedWithAssumptions(goal.missingInputs)
            }
        }

        switch goal.goalType {
        case .mailAction:
            return .proceedWithAssumptions([
                "메일 초안은 작성하되, 발송은 별도 확인이 필요합니다."
            ])
        case .calendarAction:
            return .proceedWithAssumptions([
                "일정 생성 / 수정은 아직 연결 준비 단계입니다."
            ])
        default:
            return .proceedWithAssumptions([])
        }
    }
}
