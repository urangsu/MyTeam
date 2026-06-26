import Foundation

enum NaturalWorkEntryPoint {
    static func resolve(
        text: String,
        context: NaturalWorkContext,
        chatHistory: [AgentWindowManager.ChatLog],
        agentID: String,
        agentConfig: AgentWindowManager.AgentConfig?
    ) async -> NaturalWorkRouteDecision {
        let deterministic = NaturalWorkRouter.route(for: text, context: context)
        switch deterministic {
        case .plan, .clarification, .unsupported:
            return deterministic
        case .fallback:
            break
        }

        if let plan = await AgenticToolOrchestrator.plan(
            for: text,
            context: context,
            chatHistory: chatHistory,
            agentID: agentID,
            agentConfig: agentConfig
        ) {
            return .plan(plan)
        }
        return .fallback
    }
}
