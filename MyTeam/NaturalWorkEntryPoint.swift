import Foundation

enum NaturalWorkEntryPoint {
    static func resolve(
        text: String,
        context: NaturalWorkContext,
        chatHistory: [AgentWindowManager.ChatLog]
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
            agentID: "team_all",
            agentConfig: nil
        ) {
            return .plan(plan)
        }
        return .fallback
    }
}
