import Foundation

enum GoalGate {
    static func blockedDecision(
        goal: GoalInterpretation,
        capability: CapabilityRouteDecision
    ) -> RouteDecision? {
        guard capability.status == .blocked else { return nil }
        return RouteDecision(
            kind: .blocked,
            reason: capability.message,
            skillID: nil,
            requiresApproval: true,
            expectedOutput: "blocked notice"
        )
    }
}
