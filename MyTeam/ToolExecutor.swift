import Foundation

// MARK: - ToolExecutor

actor ToolExecutor {
    static let shared = ToolExecutor()

    private(set) var directCallCount: Int = 0

    func execute(
        step: WorkflowStep,
        context: ToolExecutionContext,
        sessionID: String,
        allowedScopes: Set<ToolScope>? = nil
    ) async -> ToolResult {
        directCallCount += 1
        return await ToolExecutionLayer.execute(
            step: step,
            context: context,
            sessionID: sessionID,
            allowedScopes: allowedScopes
        )
    }

    func performExecution(
        tool: WorkflowTool,
        input: [String: String],
        context: ToolExecutionContext,
        sessionID: String,
        declaredRisk: ToolRiskLevel,
        registryRisk: ToolRiskLevel,
        effectiveRisk: ToolRiskLevel,
        baseEntry: ActionLogEntry
    ) async -> ToolResult {
        let toolName = await MainActor.run { tool.name }
        let ts = ISO8601DateFormatter().string(from: Date())
        let executionEntry = await MainActor.run {
            ActionLogEntry(
                ts: ts,
                session: sessionID,
                tool: toolName,
                inputSummary: baseEntry.inputSummary,
                inputHash: baseEntry.inputHash,
                redactedFields: baseEntry.redactedFields,
                result: "pending",
                artifact: nil,
                error: nil,
                declaredRisk: declaredRisk.rawValue,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: nil
            )
        }

        do {
            let result = try await tool.execute(input: ToolInput(parameters: input), context: context)
            let failureCode: String?
            switch result.status {
            case .succeeded:
                failureCode = nil
            case .dryRun:
                failureCode = nil
            case .blocked:
                failureCode = "tool_execution_blocked"
            case .cancelled:
                failureCode = "tool_execution_cancelled"
            case .failed:
                failureCode = "tool_execution_failed"
            }

            await ArtifactStore.shared.appendActionLog(executionEntry.with(
                result: logResultString(for: result.status),
                artifact: result.artifactPath,
                error: result.error,
                declaredRisk: declaredRisk.rawValue,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            ))
            return result
        } catch {
            let err = error.localizedDescription
            await ArtifactStore.shared.appendActionLog(executionEntry.with(
                result: "failure",
                error: err,
                declaredRisk: declaredRisk.rawValue,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: "tool_execution_failed"
            ))
            AppLog.error("[ToolExecutor] '\(toolName)' 실패: \(err)")
            return await MainActor.run {
                ToolResult.failure(err)
            }
        }
    }

    private func logResultString(for status: ToolResultStatus) -> String {
        switch status {
        case .succeeded: return "success"
        case .failed: return "failure"
        case .blocked: return "blocked"
        case .dryRun: return "dry_run"
        case .cancelled: return "cancelled"
        }
    }
}
