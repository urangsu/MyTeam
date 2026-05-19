import Foundation

enum GoalGate {
    // Round 241B: .blocked → .directChat pivot
    // 외부 쓰기(메일 전송, 캘린더 생성 등)는 실행하지 않지만
    // AI는 초안 작성·관련 도움말을 제공한다.
    // WorkflowOrchestrator의 early-return은 kind == .blocked일 때만 동작.
    static func blockedDecision(
        goal: GoalInterpretation,
        capability: CapabilityRouteDecision
    ) -> RouteDecision? {
        guard capability.status == .blocked else { return nil }
        return RouteDecision(
            kind: .directChat,
            reason: "외부 실행은 하지 않지만 내용 작성·초안을 도와드릴 수 있어요. (\(capability.message))",
            skillID: nil,
            requiresApproval: false,
            expectedOutput: "direct chat response with disclaimer"
        )
    }
}
