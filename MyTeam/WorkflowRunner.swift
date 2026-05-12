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
        legacyRunner: @escaping @Sendable () async -> PlanExecutionResult
    ) async -> PlanExecutionResult {
        _ = userMessage

        guard FeatureFlags.planRunnerUniversalDocumentEnabled else {
            return await legacyRunner()
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
            let legacyResult = await legacyRunner()
            if legacyResult.status == .completed {
                return PlanExecutionResult(
                    status: .fellBackToLegacy,
                    message: legacyResult.message,
                    artifactID: legacyResult.artifactID,
                    failureReason: legacyResult.failureReason
                )
            }
            return legacyResult
        }

        return result
    }
}
