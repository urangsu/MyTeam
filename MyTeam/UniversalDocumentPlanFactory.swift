import Foundation

enum UniversalDocumentPlanFactory {
    static func makePlan(
        request: UniversalDocumentSkillRequest,
        roomID: UUID
    ) -> WorkPlan {
        WorkPlan(
            id: UUID(),
            roomID: roomID,
            goal: request.userMessage,
            workflowKind: .universalDocument,
            steps: [
                WorkStep(
                    id: UUID(),
                    kind: .llmGenerate,
                    title: "문서 초안 생성",
                    inputKeys: ["user_message", "topic"],
                    outputKey: "draft_markdown",
                    prompt: nil,
                    verificationLevel: .markdownArtifact,
                    maxRetries: 1
                ),
                WorkStep(
                    id: UUID(),
                    kind: .verifyMarkdown,
                    title: "문서 검증",
                    inputKeys: ["draft_markdown"],
                    outputKey: "verified_markdown",
                    prompt: nil,
                    verificationLevel: .markdownArtifact,
                    maxRetries: 1
                ),
                WorkStep(
                    id: UUID(),
                    kind: .persistArtifact,
                    title: "문서 저장",
                    inputKeys: ["verified_markdown"],
                    outputKey: "artifact_id",
                    prompt: nil,
                    verificationLevel: .none,
                    maxRetries: 0
                ),
                WorkStep(
                    id: UUID(),
                    kind: .report,
                    title: "완료 보고",
                    inputKeys: ["artifact_id"],
                    outputKey: nil,
                    prompt: nil,
                    verificationLevel: .none,
                    maxRetries: 0
                )
            ],
            recoveryAction: .retryOnce,
            createdAt: Date()
        )
    }
}
