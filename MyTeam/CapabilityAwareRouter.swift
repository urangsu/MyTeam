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
                message: ApprovalCopy.message(for: .blocked)
            )
        }

        if !approval.isEmpty {
            return CapabilityRouteDecision(
                status: .requiresApproval,
                goal: goal.goalType,
                missingCapabilities: goal.requiredCapabilities.filter { $0.accessTier != .available },
                blockedCapabilities: [],
                message: ApprovalCopy.message(for: .requiresApproval)
            )
        }

        if !future.isEmpty {
            return CapabilityRouteDecision(
                status: .future,
                goal: goal.goalType,
                missingCapabilities: future,
                blockedCapabilities: [],
                message: ApprovalCopy.message(for: .future)
            )
        }

        if available.count == goal.requiredCapabilities.count {
            return CapabilityRouteDecision(
                status: .available,
                goal: goal.goalType,
                missingCapabilities: [],
                blockedCapabilities: [],
                message: ApprovalCopy.message(for: .available)
            )
        }

        return CapabilityRouteDecision(
            status: .unavailable,
            goal: goal.goalType,
            missingCapabilities: goal.requiredCapabilities,
            blockedCapabilities: [],
            message: ApprovalCopy.message(for: .unavailable)
        )
    }
}
