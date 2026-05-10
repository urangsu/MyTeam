import Foundation

enum WorkflowRunner {
    static func isAvailable() -> Bool { true }

    static func runUniversalDocumentPlan(
        _ plan: WorkPlan,
        request: UniversalDocumentSkillRequest,
        roomID: UUID,
        workflowID: UUID,
        manager: AgentWindowManager,
        allowedScopes: Set<ToolScope>
    ) async -> PlanExecutionResult {
        await PlanRunner.shared.runUniversalDocumentPlan(
            plan,
            request: request,
            roomID: roomID,
            workflowID: workflowID,
            manager: manager,
            allowedScopes: allowedScopes
        )
    }
}
