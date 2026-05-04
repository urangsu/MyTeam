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
        sessionID: String,
        allowedScopes: Set<ToolScope>? = nil
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
            await ArtifactStore.shared.appendActionLog(baseEntry.with(result: "blocked", error: msg))
            AppLog.warning("[ToolExecutor] \(msg): \(step.toolName)")
            return ToolResult.failure(msg)
        }

        // scope 화이트리스트 차단 (allowedScopes 지정 시 도구의 scope가 허용 목록에 없으면 차단)
        if let allowedScopes {
            // 도구를 먼저 조회해서 scope를 확인
            if let tool = ToolRegistry.shared.lookup(name: step.toolName) {
                if !allowedScopes.contains(tool.scope) {
                    let msg = "허용되지 않은 도구 scope '\(tool.scope.rawValue)': \(step.toolName)"
                    await ArtifactStore.shared.appendActionLog(baseEntry.with(result: "blocked", error: msg))
                    AppLog.warning("[ToolExecutor] scope 차단: \(msg)")
                    return ToolResult.failure(msg)
                }
            }
        }

        // dry-run 모드
        if context.isDryRun {
            await ArtifactStore.shared.appendActionLog(baseEntry.with(result: "dry_run"))
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
            await ArtifactStore.shared.appendActionLog(baseEntry.with(result: "failure", error: err))
            return ToolResult.failure(err)
        }

        // 실행
        do {
            let toolInput = ToolInput(parameters: step.input)
            let result = try await tool.execute(input: toolInput, context: context)
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: result.success ? "success" : "failure",
                artifact: result.artifactPath,
                error: result.error
            ))
            return result
        } catch {
            let err = error.localizedDescription
            await ArtifactStore.shared.appendActionLog(baseEntry.with(result: "failure", error: err))
            AppLog.error("[ToolExecutor] '\(step.toolName)' 실패: \(err)")
            return ToolResult.failure(err)
        }
    }
}
