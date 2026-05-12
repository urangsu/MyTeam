import Foundation

struct ToolExecutionRequest: Equatable {
    enum ToolKind: String, Codable {
        case readFile
        case writeArtifact
        case calendarRead
        case gmailMetadataRead
        case webFetch
    }

    let kind: ToolKind
    let roomID: UUID
    let requiredCapabilities: [AssistantCapability]
    let riskLevel: RiskLevel
}

enum ToolExecutionLayer {
    static func preflight(_ request: ToolExecutionRequest) -> ToolExecutionDecision {
        ConnectorGuard.evaluate(request)
    }

    static func execute(
        step: WorkflowStep,
        context: ToolExecutionContext,
        sessionID: String,
        allowedScopes: Set<ToolScope>? = nil
    ) async -> ToolResult {
        await execute(
            toolName: step.toolName,
            input: step.input,
            declaredRisk: step.riskLevel,
            context: context,
            sessionID: sessionID,
            stepTitle: step.title,
            allowedScopes: allowedScopes
        )
    }

    static func execute(
        toolName: String,
        input: [String: String],
        declaredRisk: ToolRiskLevel,
        context: ToolExecutionContext,
        sessionID: String,
        stepTitle: String? = nil,
        allowedScopes: Set<ToolScope>? = nil
    ) async -> ToolResult {
        let ts = ISO8601DateFormatter().string(from: Date())
        let baseEntry = ActionLogEntry(
            ts: ts,
            session: sessionID,
            tool: toolName,
            input: input,
            result: "pending",
            artifact: nil,
            error: nil,
            declaredRisk: declaredRisk.rawValue,
            registryRisk: nil,
            effectiveRisk: nil,
            failureCode: nil
        )

        guard let tool = ToolRegistry.shared.lookup(name: toolName) else {
            let msg = "도구를 찾을 수 없음: \(toolName)"
            await appendBlockedLog(
                baseEntry: baseEntry,
                message: msg,
                registryRisk: "missing",
                effectiveRisk: "missing",
                failureCode: "tool_registry_missing_blocked"
            )
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: msg)
        }

        let registryRisk = tool.riskLevel
        let effectiveRisk = registryRisk

        if let allowedScopes, !allowedScopes.contains(tool.scope) {
            let msg = "허용되지 않은 도구 scope '\(tool.scope.rawValue)': \(toolName)"
            await appendBlockedLog(
                baseEntry: baseEntry,
                message: msg,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: "tool_scope_missing_blocked"
            )
            AppLog.warning("[ToolExecutionLayer] scope 차단: \(msg)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: msg)
        }

        if tool.availability != .available {
            let (message, failureCode): (String, String)
            switch tool.availability {
            case .future:
                message = "아직 준비 중인 도구입니다: \(toolName)"
                failureCode = "tool_future_unavailable"
            case .requiresApproval:
                message = "이 도구는 승인이 필요합니다: \(toolName)"
                failureCode = "tool_requires_approval"
            case .unavailable:
                message = "현재 사용할 수 없는 도구입니다: \(toolName)"
                failureCode = "tool_unavailable"
            case .blocked:
                message = "이 도구는 정책상 차단되어 있습니다: \(toolName)"
                failureCode = "tool_blocked"
            case .available:
                message = "실행 가능합니다."
                failureCode = "tool_blocked"
            }
            await appendBlockedLog(
                baseEntry: baseEntry,
                message: message,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            )
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: message)
        }

        let declaredRank = riskRank(declaredRisk)
        let registryRank = riskRank(registryRisk)
        if registryRank > declaredRank {
            let message = "도구 위험 등급이 정책 기준보다 높아 실행을 차단했습니다."
            let failureCode = registryRisk == .destructive ? "tool_destructive_blocked" : "tool_risk_mismatch_blocked"
            await appendBlockedLog(
                baseEntry: baseEntry,
                message: message,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            )
            AppLog.warning("[ToolExecutionLayer] risk 차단: \(toolName) declared=\(declaredRisk.rawValue) registry=\(registryRisk.rawValue)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: message)
        }

        if registryRisk == .high || registryRisk == .destructive {
            let message = registryRisk == .destructive
                ? "파괴적 위험 도구는 현재 버전에서 실행할 수 없습니다."
                : "고위험 도구는 현재 버전에서 실행할 수 없습니다."
            let failureCode = registryRisk == .destructive ? "tool_destructive_blocked" : "tool_high_risk_blocked"
            await appendBlockedLog(
                baseEntry: baseEntry,
                message: message,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue,
                failureCode: failureCode
            )
            AppLog.warning("[ToolExecutionLayer] risk 차단: \(toolName) declared=\(declaredRisk.rawValue) registry=\(registryRisk.rawValue)")
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: message)
        }

        if context.isDryRun {
            let message = stepTitle.map { "[dry-run] '\($0)' 실행 예정" } ?? "[dry-run] '\(toolName)' 실행 예정"
            await ArtifactStore.shared.appendActionLog(baseEntry.with(
                result: "dry_run",
                declaredRisk: baseEntry.declaredRisk,
                registryRisk: registryRisk.rawValue,
                effectiveRisk: effectiveRisk.rawValue
            ))
            return ToolResult(status: .dryRun, output: message, artifactPath: nil, error: nil)
        }

        return await ToolExecutor.shared.performExecution(
            tool: tool,
            input: input,
            context: context,
            sessionID: sessionID,
            declaredRisk: declaredRisk,
            registryRisk: registryRisk,
            effectiveRisk: effectiveRisk,
            baseEntry: baseEntry
        )
    }

    static func executeWorkspaceAction(
        kind: WorkspaceFileActionKind,
        path: String,
        sessionID: String = "workspace-ui"
    ) async -> ToolResult {
        let context = ToolExecutionContext.current(
            workflowID: UUID(),
            roomID: UUID(),
            isDryRun: false
        )
        switch kind {
        case .revealInFinder:
            return await execute(
                toolName: "workspace_reveal_in_finder",
                input: ["path": path],
                declaredRisk: .safe,
                context: context,
                sessionID: sessionID,
                stepTitle: "Finder에서 열기",
                allowedScopes: [.localUI]
            )
        case .copyPath:
            return await execute(
                toolName: "workspace_copy_path",
                input: ["path": path],
                declaredRisk: .safe,
                context: context,
                sessionID: sessionID,
                stepTitle: "경로 복사",
                allowedScopes: [.localUI]
            )
        }
    }

    private static func appendBlockedLog(
        baseEntry: ActionLogEntry,
        message: String,
        registryRisk: String,
        effectiveRisk: String,
        failureCode: String
    ) async {
        await ArtifactStore.shared.appendActionLog(baseEntry.with(
            result: "blocked",
            error: message,
            declaredRisk: baseEntry.declaredRisk,
            registryRisk: registryRisk,
            effectiveRisk: effectiveRisk,
            failureCode: failureCode
        ))
    }

    private static func riskRank(_ level: ToolRiskLevel) -> Int {
        switch level {
        case .safe: return 0
        case .moderate: return 1
        case .high: return 2
        case .destructive: return 3
        }
    }
}
