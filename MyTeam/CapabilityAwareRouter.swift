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
                message: "현재 버전에서는 자동 실행할 수 없는 capability가 포함되어 있습니다."
            )
        }

        if !approval.isEmpty {
            return CapabilityRouteDecision(
                status: .requiresApproval,
                goal: goal.goalType,
                missingCapabilities: goal.requiredCapabilities.filter { $0.accessTier != .available },
                blockedCapabilities: [],
                message: "추가 확인이 필요한 capability가 포함되어 있습니다."
            )
        }

        if !future.isEmpty {
            return CapabilityRouteDecision(
                status: .future,
                goal: goal.goalType,
                missingCapabilities: future,
                blockedCapabilities: [],
                message: "아직 연결되지 않은 capability가 포함되어 있습니다."
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
            message: "현재 앱 capability를 확인할 수 없습니다."
        )
    }
}
