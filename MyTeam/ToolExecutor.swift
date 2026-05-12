import Foundation

// MARK: - ToolExecutor

final class ToolExecutor {
    static let shared = ToolExecutor()
    private init() {}

    private func riskRank(_ level: ToolRiskLevel) -> Int {
        switch level {
        case .safe: return 0
        case .moderate: return 1
        case .high: return 2
        case .destructive: return 3
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

    func execute(
        step: WorkflowStep,
        context: ToolExecutionContext,
        sessionID: String,
        allowedScopes: Set<ToolScope>? = nil
    ) async -> ToolResult {
        let ts = ISO8601DateFormatter().string(from: Date())
        let declaredRisk = step.riskLevel
        let baseEntry = ActionLogEntry(
            ts: ts,
            session: sessionID,
            tool: step.toolName,
            input: step.input,
            result: "pending",
            artifact: nil,
            error: nil,
            declaredRisk: declaredRisk.rawValue,
            registryRisk: nil,
            effectiveRisk: nil,
            failureCode: nil
        )

        guard let tool = ToolRegistry.shared.lookup(name: step.toolName) else {
            let msg = "도구를 찾을 수 없음: \(step.toolName)"
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "blocked",
                error: msg,
                registryRisk: "missing",
                effectiveRisk: "missing",
                failureCode: "tool_registry_missing_blocked"
            ))
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: msg)
        }

        let registryRisk = tool.riskLevel
        let effectiveRisk = registryRisk

        if tool.scope == .chatBasic {
            let msg = "도구 scope가 명시되지 않았습니다: \(step.toolName)"
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "blocked",
                error: msg,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: "tool_scope_missing_blocked"
            ))
            AppLog.warning("[ToolExecutor] scope 차단: \(msg)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: msg)
        }

        if let allowedScopes, !allowedScopes.contains(tool.scope) {
            let msg = "허용되지 않은 도구 scope '\(tool.scope.rawValue)': \(step.toolName)"
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "blocked",
                error: msg,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: "tool_scope_missing_blocked"
            ))
            AppLog.warning("[ToolExecutor] scope 차단: \(msg)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: msg)
        }

        let declaredRank = riskRank(declaredRisk)
        let registryRank = riskRank(registryRisk)
        let riskMismatch = declaredRank < registryRank
        let registryBlocked = registryRisk == .high || registryRisk == .destructive

        if riskMismatch || registryBlocked {
            let failureCode: String
            let message: String
            if registryRisk == .destructive {
                failureCode = "tool_destructive_blocked"
                message = "파괴적 위험 도구는 현재 버전에서 실행할 수 없습니다."
            } else if registryRisk == .high {
                failureCode = "tool_high_risk_blocked"
                message = "고위험 도구는 현재 버전에서 실행할 수 없습니다."
            } else {
                failureCode = "tool_risk_mismatch_blocked"
                message = "도구 위험 등급이 정책 기준보다 높아 실행을 차단했습니다."
            }
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "blocked",
                error: message,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            ))
            AppLog.warning("[ToolExecutor] risk 차단: \(step.toolName) declared=\(declaredRisk.rawValue) registry=\(registryRisk.rawValue)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: message)
        }

        if context.isDryRun {
            let msg = "[dry-run] '\(step.title)' 실행 예정"
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "dry_run",
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue
            ))
            return ToolResult(status: .dryRun, output: msg, artifactPath: nil, error: nil)
        }

        // 실행
        do {
            let toolInput = ToolInput(parameters: step.input)
            let result = try await tool.execute(input: toolInput, context: context)
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
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: logResultString(for: result.status),
                artifact: result.artifactPath,
                error: result.error,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            ))
            return result
        } catch {
            let err = error.localizedDescription
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "failure",
                error: err,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: "tool_execution_failed"
            ))
            AppLog.error("[ToolExecutor] '\(step.toolName)' 실패: \(err)")
            return ToolResult.failure(err)
        }
    }
}
