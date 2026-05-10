import Foundation

enum WorkflowRunner {
    static func isAvailable() -> Bool { true }

    static func runDailyBriefing(
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> DailyBriefing {
        _ = roomID
        return await DailyBriefingService.makePreviewBriefing(
            now: Date(),
            calendarProvider: GoogleDailyBriefingCalendarProvider.shared,
            manager: manager
        )
    }

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
