import Foundation

struct CapabilityRouteDecision: Equatable {
    enum Status: String, Codable {
        case available
        case unavailable
        case requiresApproval
        case blocked
        case future
    }

    let status: Status
    let goal: GoalInterpretation.GoalType
    let missingCapabilities: [AssistantCapability]
    let blockedCapabilities: [AssistantCapability]
    let message: String
}

enum CapabilityAwareRouter {
    static func evaluate(goal: GoalInterpretation) -> CapabilityRouteDecision {
        let blocked = goal.requiredCapabilities.filter { $0.accessTier == .blocked }
        let approval = goal.requiredCapabilities.filter { $0.accessTier == .requiresApproval }
        let future = goal.requiredCapabilities.filter { $0.accessTier == .future }
        let available = goal.requiredCapabilities.filter { $0.accessTier == .available }

        if !blocked.isEmpty {
            return CapabilityRouteDecision(
                status: .blocked,
                goal: goal.goalType,
                missingCapabilities: goal.requiredCapabilities,
                blockedCapabilities: blocked,
                message: "이 작업은 안전 정책상 자동 실행하지 않습니다."
            )
        }

        if !approval.isEmpty {
            return CapabilityRouteDecision(
                status: .requiresApproval,
                goal: goal.goalType,
                missingCapabilities: goal.requiredCapabilities.filter { $0.accessTier != .available },
                blockedCapabilities: [],
                message: "이 작업은 승인이 필요합니다. 자동 실행하지 않고 승인 대기로 남겨둘게요."
            )
        }

        if !future.isEmpty {
            return CapabilityRouteDecision(
                status: .future,
                goal: goal.goalType,
                missingCapabilities: future,
                blockedCapabilities: [],
                message: "이 기능은 준비 중입니다. 현재 지원되는 기능으로 먼저 도와드릴게요."
            )
        }

        if available.count == goal.requiredCapabilities.count {
            return CapabilityRouteDecision(
                status: .available,
                goal: goal.goalType,
                missingCapabilities: [],
                blockedCapabilities: [],
                message: "현재 앱 capability로 처리할 수 있습니다."
            )
        }

        return CapabilityRouteDecision(
            status: .unavailable,
            goal: goal.goalType,
            missingCapabilities: goal.requiredCapabilities,
            blockedCapabilities: [],
            message: "이 기능은 아직 사용할 수 없습니다. 현재는 로컬 파일/문서 기능을 사용할 수 있습니다."
        )
    }
}
