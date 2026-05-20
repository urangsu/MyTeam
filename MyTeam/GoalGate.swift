import Foundation

enum GoalGate {
    // Round 246A: blockedDecision → executionFallbackDecision (rename)
    // capability가 blocked일 때 .directChat을 반환해 LLM이 초안/도움말을 제공하게 한다.
    // WorkflowOrchestrator는 이 결과를 받아 runDirectChatFallback()으로 실제 LLM을 호출해야 한다.
    // 안내문만 띄우고 return하면 안 됨 — LLM까지 가야 함.
    static func executionFallbackDecision(
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
