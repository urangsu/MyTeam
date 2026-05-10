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

    static func runUniversalDocument(
        plan: WorkPlan,
        request: UniversalDocumentSkillRequest,
        userMessage: String,
        roomID: UUID,
        workflowID: UUID,
        manager: AgentWindowManager,
        allowedScopes: Set<ToolScope>,
        legacyRunner: @escaping @Sendable () async -> Void
    ) async -> PlanExecutionResult {
        _ = userMessage

        guard FeatureFlags.planRunnerUniversalDocumentEnabled else {
            await legacyRunner()
            return PlanExecutionResult(
                status: .fellBackToLegacy,
                message: "legacy workflow used",
                artifactID: nil,
                failureReason: .none
            )
        }

        let result = await runUniversalDocumentPlan(
            plan,
            request: request,
            roomID: roomID,
            workflowID: workflowID,
            manager: manager,
            allowedScopes: allowedScopes
        )

        if result.failureReason == .recoverableRuntimeError {
            await legacyRunner()
            return PlanExecutionResult(
                status: .fellBackToLegacy,
                message: result.message,
                artifactID: nil,
                failureReason: .recoverableRuntimeError
            )
        }

        return result
    }
}
