import Foundation

// MARK: - RuntimeDiagnosticsSnapshot
// 특정 시점 시스템 상태의 읽기 전용 스냅샷.
// UI 연결은 다음 단계 — 이번에는 snapshot 생성 골격만.

struct RuntimeDiagnosticsSnapshot {
    let capturedAt: Date

    // Room / Workflow
    let currentRoomID: UUID?
    let activeWorkflowID: UUID?
    let isWorkflowRunning: Bool

    // Gemini
    let geminiCooldownRemainingSeconds: Double?   // nil이면 쿨다운 없음
    let geminiConsecutive429Count: Int

    // AICallBudget
    let budgetUsageDescription: String

    // Qwen TTS
    let qwenEnabled: Bool
    let qwenUnavailable: Bool

    // STT
    let sttInitialized: Bool
    let sttRecording: Bool
    let sttStarting: Bool

    // Artifacts
    let recentArtifactsCount: Int

    // Routing / Turn profile
    let lastTurnRoute: String?
    let lastRouteReason: String?
    let lastMatchedSkills: [String]
    let lastEffectiveScopes: [String]
    let recentRouteTraceCount: Int

    // Router burn-in / tool contract validation
    let routerBurnInTotal: Int
    let routerBurnInPassed: Int
    let routerBurnInFailed: Int
    let toolContractErrors: Int
    let toolContractWarnings: Int

    // Delegation
    let delegationModeStatus: String?
    let activeDelegationGoal: String?
    let delegatedPlanStepCount: Int
    let pendingDelegatedRouteHint: String?
    let pendingDelegatedExecutionStatus: String?

    // Assistant connectors
    let assistantConnectorCount: Int
    let assistantConnectorImplementedCount: Int
    let assistantConnectorConnectedCount: Int

    // Google OAuth
    let googleOAuthConfigStatus: String
    let googleOAuthEnabledScopes: [String]
    let googleOAuthHasCalendarToken: Bool

    // Daily briefing
    let dailyBriefingStatus: String
    let dailyBriefingCalendarItemCount: Int
    let dailyBriefingMailItemCount: Int

    // Workspace
    let workspacePath: String

    // AgentEventBus
    let recentEventCount: Int
    let latestEventSummary: String?

    // MARK: - Human-readable summary

    var summary: String {
        var lines: [String] = ["[RuntimeDiagnostics] \(capturedAt.formatted(.iso8601))"]

        lines.append("roomID: \(currentRoomID?.uuidString.prefix(8) ?? "nil")")
        lines.append("workflowID: \(activeWorkflowID?.uuidString.prefix(8) ?? "nil")")
        lines.append("isWorkflowRunning: \(isWorkflowRunning)")

        if let sec = geminiCooldownRemainingSeconds {
            lines.append("geminiCooldown: \(Int(sec))s remaining (429×\(geminiConsecutive429Count))")
        } else {
            lines.append("geminiCooldown: none")
        }

        lines.append("budget: \(budgetUsageDescription)")
        lines.append("qwen: enabled=\(qwenEnabled) unavailable=\(qwenUnavailable)")
        lines.append("stt: initialized=\(sttInitialized) recording=\(sttRecording) starting=\(sttStarting)")
        lines.append("recentArtifacts: \(recentArtifactsCount)")
        lines.append("lastTurnRoute: \(lastTurnRoute ?? "nil")")
        if let reason = lastRouteReason, !reason.isEmpty {
            lines.append("lastRouteReason: \(reason)")
        }
        if !lastMatchedSkills.isEmpty {
            lines.append("matchedSkills: \(lastMatchedSkills.joined(separator: ", "))")
        }
        if !lastEffectiveScopes.isEmpty {
            lines.append("effectiveScopes: \(lastEffectiveScopes.joined(separator: ", "))")
        }
        lines.append("recentRouteTraceCount: \(recentRouteTraceCount)")
        lines.append("validation: router \(routerBurnInPassed)/\(routerBurnInTotal) passed | tool contracts errors=\(toolContractErrors) warnings=\(toolContractWarnings)")
        if let delegationModeStatus {
            lines.append("delegation: \(delegationModeStatus) goal=\(activeDelegationGoal ?? "nil") steps=\(delegatedPlanStepCount)")
        } else {
            lines.append("delegation: inactive")
        }
        if let pendingDelegatedRouteHint {
            lines.append("delegationPending: \(pendingDelegatedRouteHint) status=\(pendingDelegatedExecutionStatus ?? "nil")")
        }
        lines.append("assistantConnectors: total=\(assistantConnectorCount) implemented=\(assistantConnectorImplementedCount) connected=\(assistantConnectorConnectedCount)")
        lines.append("googleOAuth: status=\(googleOAuthConfigStatus) scopes=\(googleOAuthEnabledScopes.joined(separator: ",")) token=\(googleOAuthHasCalendarToken)")
        lines.append("dailyBriefing: status=\(dailyBriefingStatus) calendar=\(dailyBriefingCalendarItemCount) mail=\(dailyBriefingMailItemCount)")
        lines.append("workspace: \(workspacePath)")
        lines.append("recentEvents: \(recentEventCount) | latest: \(latestEventSummary ?? "none")")

        return lines.joined(separator: "\n  ")
    }
}

// MARK: - RuntimeDiagnosticsService

@MainActor
final class RuntimeDiagnosticsService {
    static let shared = RuntimeDiagnosticsService()
    private init() {}

    /// 현재 상태 스냅샷 생성
    func snapshot(manager: AgentWindowManager) async -> RuntimeDiagnosticsSnapshot {
        let speech = SpeechManager.shared
        let ai = AIService.shared
        let budget = AICallBudgetManager.shared
        let capture = AudioCaptureService.shared

        let qwen = speech.qwenDiagnostics
        let workspacePath = ToolExecutionContext.workspaceURL.path

        let recentEvents = await AgentEventBus.shared.allRecentEvents(limit: 100)
        let latestEvent = recentEvents.last
        let latestSummary = latestEvent.map { "\($0.type.rawValue) wf=\($0.workflowID?.uuidString.prefix(8) ?? "-")" }
        let currentRoomID = manager.currentRoomID
        let lastProfile = currentRoomID.flatMap { manager.lastTurnProfile(for: $0) }
        let recentRouteTraceCount = currentRoomID.map { manager.recentRouteTraces(for: $0).count } ?? 0
        let delegationState = currentRoomID.flatMap { manager.delegationModeState(for: $0) }
        let delegationContract = currentRoomID.flatMap { manager.activeDelegationContract(for: $0) }
        let delegationPlan = currentRoomID.flatMap { manager.delegatedWorkflowPlan(for: $0) }
        let pendingDelegatedRequest = currentRoomID.flatMap { manager.pendingDelegatedExecutionRequest(for: $0) }
        let routerBurnInSummary = await MainActor.run { RouterBurnInSuite.runAll() }
        let toolContractSummary = ToolContractValidator.validate()
        let assistantConnectorCount = AssistantConnectorCatalog.connectors.count
        let assistantConnectorImplementedCount = AssistantConnectorCatalog.connectors.filter { $0.isImplemented }.count
        let assistantConnectorConnectedCount = AssistantConnectorCatalog.connectors.filter {
            GoogleOAuthTokenStore.shared.hasToken(for: $0.id)
        }.count
        let googleStoredConfig = GoogleOAuthConfigStore.shared.load()
        let googleConfigValidation = GoogleOAuthConfigValidator.validate(googleStoredConfig)
        let googleOAuthHasCalendarToken = GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar)
        let dailyBriefing = await DailyBriefingService.makePreviewBriefing(
            now: Date(),
            calendarProvider: EmptyDailyBriefingCalendarProvider()
        )

        return RuntimeDiagnosticsSnapshot(
            capturedAt: Date(),
            currentRoomID: currentRoomID,
            activeWorkflowID: manager.currentWorkflowID,
            isWorkflowRunning: manager.isWorkflowRunning,
            geminiCooldownRemainingSeconds: ai.geminiCooldownRemainingSeconds,
            geminiConsecutive429Count: ai.consecutive429Count,
            budgetUsageDescription: budget.usageDescription(),
            qwenEnabled: qwen.enabled,
            qwenUnavailable: qwen.unavailable,
            sttInitialized: capture.audioEngineInitialized,
            sttRecording: capture.isRecording,
            sttStarting: capture.isStarting,
            recentArtifactsCount: manager.recentArtifacts.count,
            lastTurnRoute: lastProfile.map { $0.selectedRoute.rawValue },
            lastRouteReason: lastProfile?.routeReason,
            lastMatchedSkills: lastProfile?.matchedSkillIDs ?? [],
            lastEffectiveScopes: lastProfile?.effectiveScopes ?? [],
            recentRouteTraceCount: recentRouteTraceCount,
            routerBurnInTotal: routerBurnInSummary.total,
            routerBurnInPassed: routerBurnInSummary.passed,
            routerBurnInFailed: routerBurnInSummary.failed,
            toolContractErrors: toolContractSummary.errorCount,
            toolContractWarnings: toolContractSummary.warningCount,
            delegationModeStatus: delegationState.map { $0.status.rawValue },
            activeDelegationGoal: delegationContract?.goal ?? delegationState?.detail,
            delegatedPlanStepCount: delegationPlan?.steps.count ?? 0,
            pendingDelegatedRouteHint: pendingDelegatedRequest?.routeHint,
            pendingDelegatedExecutionStatus: pendingDelegatedRequest?.status.rawValue,
            assistantConnectorCount: assistantConnectorCount,
            assistantConnectorImplementedCount: assistantConnectorImplementedCount,
            assistantConnectorConnectedCount: assistantConnectorConnectedCount,
            googleOAuthConfigStatus: googleConfigValidation.status.rawValue,
            googleOAuthEnabledScopes: googleStoredConfig.enabledScopes.map(\.rawValue),
            googleOAuthHasCalendarToken: googleOAuthHasCalendarToken,
            dailyBriefingStatus: dailyBriefing.status.rawValue,
            dailyBriefingCalendarItemCount: dailyBriefing.calendarItems.count,
            dailyBriefingMailItemCount: dailyBriefing.mailItems.count,
            workspacePath: workspacePath,
            recentEventCount: recentEvents.count,
            latestEventSummary: latestSummary
        )
    }

    /// 콘솔에 현재 상태 출력 (디버그용)
    func dump(manager: AgentWindowManager) {
        Task { @MainActor in
            let snap = await self.snapshot(manager: manager)
            AppLog.info(snap.summary)
        }
    }
}
