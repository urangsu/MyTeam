import Foundation

enum AgentPipelineFactory {
    static func basicDocumentReviewPipeline() -> [AgentWorkOrder] {
        [
            AgentWorkOrder(
                role: .researcher,
                title: "핵심 자료 정리",
                instruction: "사용자 요청과 입력 자료에서 핵심 사실, 조건, 누락 정보를 정리하세요.",
                inputKeys: ["user_message", "source_text"],
                outputKey: "research_notes",
                verificationLevel: .chatAnswer,
                maxRetries: 0
            ),
            AgentWorkOrder(
                role: .drafter,
                title: "초안 작성",
                instruction: "research_notes를 바탕으로 업무용 초안을 작성하세요. 캐릭터 대사는 넣지 마세요.",
                inputKeys: ["user_message", "research_notes"],
                outputKey: "draft",
                verificationLevel: .markdownArtifact,
                maxRetries: 1
            ),
            AgentWorkOrder(
                role: .reviewer,
                title: "검토",
                instruction: "draft를 검토하고 누락, 모호함, 개선점을 짧게 정리하세요.",
                inputKeys: ["draft"],
                outputKey: "review_notes",
                verificationLevel: .chatAnswer,
                maxRetries: 0
            )
        ]
    }
}
