import Foundation

// MARK: - ToolExecutor

final class ToolExecutor {
    static let shared = ToolExecutor()
    private init() {}

    /// MVP에서 실행 금지 위험 등급
    private let blockedRiskLevels: Set<ToolRiskLevel> = [.high, .destructive]

    func execute(
        step: WorkflowStep,
        context: ToolExecutionContext,
        sessionID: String
    ) async -> ToolResult {
        let ts = ISO8601DateFormatter().string(from: Date())
        let baseEntry = ActionLogEntry(
            ts: ts,
            session: sessionID,
            tool: step.toolName,
            input: step.input,
            result: "pending",
            artifact: nil,
            error: nil
        )

        // high/destructive 차단
        if blockedRiskLevels.contains(step.riskLevel) {
            let msg = "MVP에서 \(step.riskLevel.rawValue) 위험 도구 실행 금지"
            ArtifactStore.shared.appendActionLog(baseEntry.with(result: "blocked", error: msg))
            AppLog.warning("[ToolExecutor] \(msg): \(step.toolName)")
            return ToolResult.failure(msg)
        }

        // dry-run 모드
        if context.isDryRun {
            ArtifactStore.shared.appendActionLog(baseEntry.with(result: "dry_run"))
            return ToolResult(
                success: true,
                output: "[dry-run] '\(step.title)' 실행 예정",
                artifactPath: nil,
                error: nil
            )
        }

        // 도구 조회
        guard let tool = ToolRegistry.shared.lookup(name: step.toolName) else {
            let err = "도구를 찾을 수 없음: \(step.toolName)"
            ArtifactStore.shared.appendActionLog(baseEntry.with(result: "failure", error: err))
            return ToolResult.failure(err)
        }

        // 실행
        do {
            let toolInput = ToolInput(parameters: step.input)
            let result = try await tool.execute(input: toolInput, context: context)
            ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: result.success ? "success" : "failure",
                artifact: result.artifactPath,
                error: result.error
            ))
            return result
        } catch {
            let err = error.localizedDescription
            ArtifactStore.shared.appendActionLog(baseEntry.with(result: "failure", error: err))
            AppLog.error("[ToolExecutor] '\(step.toolName)' 실패: \(err)")
            return ToolResult.failure(err)
        }
    }
}
