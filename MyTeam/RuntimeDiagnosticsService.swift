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
    let activeTaskRoomCount: Int

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
    let lastGoalType: String?
    let lastGoalConfidence: String?
    let lastCapabilityRouteStatus: String?
    let lastGoalRequiredCapabilities: [String]
    let lastUniversalDocumentType: String?
    let lastRoomGoalType: String?
    let lastActiveWorkflowStep: String?
    let recentArtifactReferenceAvailable: Bool
    let blockedCapabilityGateEnabled: Bool
    let resultVerifierErrorGateEnabled: Bool
    let dailyBriefingAvailable: Bool
    let localBriefingAvailable: Bool
    let localTaskBriefingAvailable: Bool
    let calendarProviderAvailable: Bool
    let gmailMetadataAvailable: Bool
    let connectorBlockedActions: [String]
    let lastBriefingSectionCount: Int
    let localTaskBriefingItemCount: Int
    let localTaskBriefingHighPriorityCount: Int
    let lastLocalTaskBriefingKinds: [String]
    let localTaskBriefingActionCount: Int
    let localTaskBriefingSuggestedActionCount: Int
    let localTaskBriefingUnsupportedActionCount: Int
    let recentArtifactContentResolverAvailable: Bool
    let recentArtifactReuseAvailable: Bool
    let recentArtifactReusableCount: Int
    let lastRecentArtifactReuseSourceName: String?
    let recentArtifactReuseSupportedTypes: [String]
    let connectorPolicyCentralized: Bool
    let workflowRunnerDailyBriefingEnabled: Bool
    let workflowRunnerUniversalDocumentPlanEnabled: Bool
    let orchestratorBoundaryReduced: Bool
    let roomRuntimeStoreAvailable: Bool
    let roomRuntimeStoreOwnsGoalContext: Bool
    let roomRuntimeStoreOwnsFileIntake: Bool
    let roomRuntimeStoreOwnsActiveTasks: Bool
    let agentWindowManagerFacadeMode: Bool

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
    let googleCalendarConnectionStatus: String
    let googleCalendarLastFetchStatus: String

    // Daily briefing
    let dailyBriefingStatus: String
    let dailyBriefingCalendarItemCount: Int
    let dailyBriefingMailItemCount: Int
    let localBriefingItemCount: Int
    let universalDocumentSkillCount: Int
    let universalDocumentRouteAvailable: Bool
    let routeResolverAvailable: Bool
    let workflowRunnerAvailable: Bool
    let toolExecutionLayerAvailable: Bool
    let connectorGuardAvailable: Bool
    let planRunnerAvailable: Bool
    let planRunnerUniversalDocumentEnabled: Bool
    let planRunnerFailureReasonAware: Bool
    let agentPipelineAvailable: Bool
    let defaultPipelineOrderCount: Int
    let pipelineContextAvailable: Bool
    let executionContractAvailable: Bool
    let executionContextBagAvailable: Bool
    let executionVerifierAvailable: Bool
    let planPipelineContractAligned: Bool
    let legacyFallbackOutcomeAware: Bool
    let fileIntakeAvailable: Bool
    let fileIntakeReadableExtensions: [String]
    let fileIntakePlannedExtensions: [String]
    let fileIntakeMaxFileSizeMB: Int
    let lastFileIntakeStatus: String?
    let lastFileIntakeFilename: String?
    let lastFileIntakeHasExtractedText: Bool
    let lastFileIntakeExtractedCharacterCount: Int
    let fileIntakeToDocumentAvailable: Bool

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
        lines.append("activeTaskRooms: \(activeTaskRoomCount)")

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
        if let lastGoalType {
            lines.append("goal: \(lastGoalType) confidence=\(lastGoalConfidence ?? "nil") capability=\(lastCapabilityRouteStatus ?? "nil") caps=\(lastGoalRequiredCapabilities.joined(separator: ","))")
        }
        if let lastUniversalDocumentType {
            lines.append("universalDocument: \(lastUniversalDocumentType)")
        }
        if lastRoomGoalType != nil || lastActiveWorkflowStep != nil {
            lines.append("roomGoal: \(lastRoomGoalType ?? "nil") step=\(lastActiveWorkflowStep ?? "nil") recentArtifactRef=\(recentArtifactReferenceAvailable)")
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
        lines.append("googleCalendar: connection=\(googleCalendarConnectionStatus) fetch=\(googleCalendarLastFetchStatus)")
        lines.append("dailyBriefing: status=\(dailyBriefingStatus) calendar=\(dailyBriefingCalendarItemCount) mail=\(dailyBriefingMailItemCount) localItems=\(localBriefingItemCount)")
        lines.append("briefingAvailability: daily=\(dailyBriefingAvailable) local=\(localBriefingAvailable) localTask=\(localTaskBriefingAvailable) calendarProvider=\(calendarProviderAvailable) gmailMetadata=\(gmailMetadataAvailable) sections=\(lastBriefingSectionCount)")
        lines.append("localTaskBriefing: items=\(localTaskBriefingItemCount) high=\(localTaskBriefingHighPriorityCount) kinds=\(lastLocalTaskBriefingKinds.joined(separator: ","))")
        lines.append("localTaskBriefingActions: supported=\(localTaskBriefingActionCount) suggested=\(localTaskBriefingSuggestedActionCount) unsupported=\(localTaskBriefingUnsupportedActionCount) recentArtifactResolver=\(recentArtifactContentResolverAvailable)")
        lines.append("recentArtifactReuse: available=\(recentArtifactReuseAvailable) count=\(recentArtifactReusableCount) source=\(lastRecentArtifactReuseSourceName ?? "nil") types=\(recentArtifactReuseSupportedTypes.joined(separator: ","))")
        if !connectorBlockedActions.isEmpty {
            let preview = Array(connectorBlockedActions.prefix(5))
            let remaining = connectorBlockedActions.count - preview.count
            let suffix = remaining > 0 ? " ... +\(remaining)" : ""
            lines.append("connectorBlockedActions(\(connectorBlockedActions.count)): \(preview.joined(separator: ", "))\(suffix)")
        }
        lines.append("connectorPolicyCentralized: \(connectorPolicyCentralized)")
        lines.append("workflowRunnerDailyBriefingEnabled: \(workflowRunnerDailyBriefingEnabled)")
        lines.append("workflowRunnerUniversalDocumentPlanEnabled: \(workflowRunnerUniversalDocumentPlanEnabled)")
        lines.append("orchestratorBoundaryReduced: \(orchestratorBoundaryReduced)")
        lines.append("roomRuntimeStore: available=\(roomRuntimeStoreAvailable) goal=\(roomRuntimeStoreOwnsGoalContext) fileIntake=\(roomRuntimeStoreOwnsFileIntake) tasks=\(roomRuntimeStoreOwnsActiveTasks) facade=\(agentWindowManagerFacadeMode)")
        lines.append("universalDocument: skills=\(universalDocumentSkillCount) available=\(universalDocumentRouteAvailable)")
        lines.append("routeResolver: available=\(routeResolverAvailable)")
        lines.append("workflowRunner: available=\(workflowRunnerAvailable)")
        lines.append("toolExecutionLayer: available=\(toolExecutionLayerAvailable)")
        lines.append("connectorGuard: available=\(connectorGuardAvailable)")
        lines.append("planRunner: available=\(planRunnerAvailable) enabled=\(planRunnerUniversalDocumentEnabled)")
        lines.append("planRunnerFailureReasonAware: \(planRunnerFailureReasonAware)")
        lines.append("agentPipeline: available=\(agentPipelineAvailable) defaultSteps=\(defaultPipelineOrderCount) context=\(pipelineContextAvailable)")
        lines.append("executionContract: available=\(executionContractAvailable) contextBag=\(executionContextBagAvailable) verifier=\(executionVerifierAvailable) aligned=\(planPipelineContractAligned) fallbackAware=\(legacyFallbackOutcomeAware)")
        lines.append("fileIntake: available=\(fileIntakeAvailable) readable=\(fileIntakeReadableExtensions.joined(separator: ",")) planned=\(fileIntakePlannedExtensions.joined(separator: ",")) max=\(fileIntakeMaxFileSizeMB)MB")
        if let lastFileIntakeStatus {
            lines.append("fileIntakeLast: status=\(lastFileIntakeStatus) file=\(lastFileIntakeFilename ?? "nil") text=\(lastFileIntakeHasExtractedText) chars=\(lastFileIntakeExtractedCharacterCount)")
        }
        lines.append("fileIntakeToDocument: available=\(fileIntakeToDocumentAvailable)")
        lines.append("safety: blockedCapabilityGate=\(blockedCapabilityGateEnabled) resultVerifierErrorGate=\(resultVerifierErrorGateEnabled)")
        lines.append("autonomy: goalInterpreter=true clarificationPolicy=true capabilityRouter=true resultVerifier=true")
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
        let lastGoal = currentRoomID.flatMap { manager.lastGoalInterpretation(for: $0) }
        let lastCapabilityRouteDecision = currentRoomID.flatMap { manager.lastCapabilityRouteDecision(for: $0) }
        let lastUniversalDocumentType = currentRoomID.flatMap { manager.lastUniversalDocumentType(for: $0) }
        let roomGoalContext = await MainActor.run { currentRoomID.flatMap { manager.roomGoalContext(for: $0) } }
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
        let googleCalendarConnectionState = AssistantConnectorCatalog.connectionState(for: .googleCalendar)
        let googleCalendarLastFetchStatus = GoogleDailyBriefingCalendarProvider.shared.lastFetchStatus
        let dailyBriefing = await DailyBriefingService.makePreviewBriefing(
            now: Date(),
            calendarProvider: EmptyDailyBriefingCalendarProvider(),
            manager: manager
        )
        let localBriefing = DailyBriefingLocalProvider.makeSnapshot(roomID: currentRoomID, manager: manager)
        let localTaskBriefingItems = localBriefing.localBriefingItems
        let localTaskBriefingActionCount = localBriefing.localTaskActionCount
        let localTaskBriefingSuggestedActionCount = localBriefing.localTaskSuggestedActionCount
        let localTaskBriefingUnsupportedActionCount = localBriefing.localTaskUnsupportedActionCount
        let recentArtifactContentResolverAvailable = localBriefing.recentArtifactContentResolverAvailable
        let recentArtifactReusableCount = localBriefing.recentArtifactReusableCount
        let recentArtifactReuseAvailable = recentArtifactContentResolverAvailable && recentArtifactReusableCount > 0
        let lastRecentArtifactReuseSourceName = await MainActor.run {
            currentRoomID.flatMap {
                RecentArtifactContentResolver.resolveLatestMarkdownArtifact(roomID: $0, manager: manager)?.sourceName
            }
        }
        let recentArtifactReuseSupportedTypes = ["summary", "reportDraft", "checklist", "tableSummary", "meetingMinutes", "actionItems"]
        let connectorBlockedActions = AssistantConnectorCatalog.connectors.flatMap { connector -> [String] in
            connector.capabilities.compactMap { capability in
                if case .blocked = AssistantConnectorPolicy.decision(for: capability) {
                    return "\(connector.displayName): \(capability.displayName)"
                }
                return nil
            }
        }
        let briefingSectionCount = [
            !dailyBriefing.calendarItems.isEmpty,
            !dailyBriefing.mailItems.isEmpty,
            !dailyBriefing.taskItems.isEmpty || !localBriefing.taskItems.isEmpty,
            !dailyBriefing.attentionItems.isEmpty || !localBriefing.attentionItems.isEmpty
        ].filter { $0 }.count
        let universalDocumentSkillCount = SkillRegistry.shared.allSkillManifests.filter { $0.id.hasPrefix("korean.document-") || $0.id == "korean.report-draft" || $0.id == "korean.checklist" || $0.id == "korean.table-summary" || $0.id == "korean.meeting-minutes" || $0.id == "korean.action-items" }.count
        let universalDocumentRouteAvailable = SkillRegistry.shared.allEnabledSkills().contains {
            $0.id.hasPrefix("korean.document-") || $0.id == "korean.report-draft" || $0.id == "korean.checklist" || $0.id == "korean.table-summary" || $0.id == "korean.meeting-minutes" || $0.id == "korean.action-items"
        }
        let routeResolverAvailable = true
        let workflowRunnerAvailable = WorkflowRunner.isAvailable()
        let toolExecutionLayerAvailable = true
        let connectorGuardAvailable = true
        let planRunnerAvailable = true
        let planRunnerUniversalDocumentEnabled = FeatureFlags.planRunnerUniversalDocumentEnabled
        let planRunnerFailureReasonAware = true
        let agentPipelineAvailable = true
        let defaultPipelineOrderCount = AgentPipelineFactory.basicDocumentReviewPipeline().count
        let pipelineContextAvailable = true
        let executionContractAvailable = true
        let executionContextBagAvailable = true
        let executionVerifierAvailable = true
        let planPipelineContractAligned = true
        let legacyFallbackOutcomeAware = true
        let fileIntakeAvailable = true
        let fileIntakeReadableExtensions = FileIntakePolicy.readableExtensions.sorted()
        let fileIntakePlannedExtensions = FileIntakePolicy.plannedExtensions.sorted()
        let fileIntakeMaxFileSizeMB = Int(FileIntakePolicy.maxFileSizeBytes / (1024 * 1024))
        let currentFileIntakeResult = await MainActor.run { currentRoomID.flatMap { manager.lastFileIntakeResult(for: $0) } }
        let lastFileIntakeStatus = currentFileIntakeResult?.status.rawValue
        let lastFileIntakeFilename = currentFileIntakeResult?.request.originalFilename
        let lastFileIntakeHasExtractedText = currentFileIntakeResult?.extractedText?.isEmpty == false
        let lastFileIntakeExtractedCharacterCount = currentFileIntakeResult?.extractedText?.count ?? 0
        let fileIntakeToDocumentAvailable = currentFileIntakeResult?.status == .ready && lastFileIntakeHasExtractedText
        let activeTaskRoomCount = manager.activeWorkflowTaskCount()
        let lastRoomGoalType = roomGoalContext?.currentGoal?.goalType.rawValue
        let lastActiveWorkflowStep = roomGoalContext?.activeWorkflowStep
        let recentArtifactReferenceAvailable = roomGoalContext.map { !$0.recentArtifactIDs.isEmpty } ?? false
        let blockedCapabilityGateEnabled = true
        let resultVerifierErrorGateEnabled = true
        let connectorPolicyCentralized = true
        let workflowRunnerDailyBriefingEnabled = true
        let workflowRunnerUniversalDocumentPlanEnabled = true
        let orchestratorBoundaryReduced = true
        let roomRuntimeStoreAvailable = manager.roomRuntimeStore.isAvailable
        let roomRuntimeStoreOwnsGoalContext = manager.roomRuntimeStore.ownsGoalContext
        let roomRuntimeStoreOwnsFileIntake = manager.roomRuntimeStore.ownsFileIntake
        let roomRuntimeStoreOwnsActiveTasks = manager.roomRuntimeStore.ownsActiveTasks
        let agentWindowManagerFacadeMode = true

        return RuntimeDiagnosticsSnapshot(
            capturedAt: Date(),
            currentRoomID: currentRoomID,
            activeWorkflowID: manager.currentWorkflowID,
            isWorkflowRunning: manager.isWorkflowRunning,
            activeTaskRoomCount: activeTaskRoomCount,
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
            lastGoalType: lastGoal.map { $0.goalType.rawValue },
            lastGoalConfidence: lastGoal.map { $0.confidence.rawValue },
            lastCapabilityRouteStatus: lastCapabilityRouteDecision.map { $0.status.rawValue },
            lastGoalRequiredCapabilities: lastGoal?.requiredCapabilities.map { $0.rawValue } ?? [],
            lastUniversalDocumentType: lastUniversalDocumentType?.rawValue,
            lastRoomGoalType: lastRoomGoalType,
            lastActiveWorkflowStep: lastActiveWorkflowStep,
            recentArtifactReferenceAvailable: recentArtifactReferenceAvailable,
            blockedCapabilityGateEnabled: blockedCapabilityGateEnabled,
            resultVerifierErrorGateEnabled: resultVerifierErrorGateEnabled,
            dailyBriefingAvailable: true,
            localBriefingAvailable: DailyBriefingLocalProvider.isAvailable,
            localTaskBriefingAvailable: DailyBriefingLocalProvider.isAvailable,
            calendarProviderAvailable: AssistantConnectorCatalog.connectionState(for: .googleCalendar).status != .comingSoon,
            gmailMetadataAvailable: AssistantConnectorCatalog.connectionState(for: .gmail).status != .comingSoon,
            connectorBlockedActions: connectorBlockedActions,
            lastBriefingSectionCount: briefingSectionCount,
            localTaskBriefingItemCount: localTaskBriefingItems.count,
            localTaskBriefingHighPriorityCount: localTaskBriefingItems.filter { $0.priority == .high }.count,
            lastLocalTaskBriefingKinds: Array(localTaskBriefingItems.prefix(5).map(\.kind.rawValue)),
            localTaskBriefingActionCount: localTaskBriefingActionCount,
            localTaskBriefingSuggestedActionCount: localTaskBriefingSuggestedActionCount,
            localTaskBriefingUnsupportedActionCount: localTaskBriefingUnsupportedActionCount,
            recentArtifactContentResolverAvailable: recentArtifactContentResolverAvailable,
            recentArtifactReuseAvailable: recentArtifactReuseAvailable,
            recentArtifactReusableCount: recentArtifactReusableCount,
            lastRecentArtifactReuseSourceName: lastRecentArtifactReuseSourceName,
            recentArtifactReuseSupportedTypes: recentArtifactReuseSupportedTypes,
            connectorPolicyCentralized: connectorPolicyCentralized,
            workflowRunnerDailyBriefingEnabled: workflowRunnerDailyBriefingEnabled,
            workflowRunnerUniversalDocumentPlanEnabled: workflowRunnerUniversalDocumentPlanEnabled,
            orchestratorBoundaryReduced: orchestratorBoundaryReduced,
            roomRuntimeStoreAvailable: roomRuntimeStoreAvailable,
            roomRuntimeStoreOwnsGoalContext: roomRuntimeStoreOwnsGoalContext,
            roomRuntimeStoreOwnsFileIntake: roomRuntimeStoreOwnsFileIntake,
            roomRuntimeStoreOwnsActiveTasks: roomRuntimeStoreOwnsActiveTasks,
            agentWindowManagerFacadeMode: agentWindowManagerFacadeMode,
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
            googleCalendarConnectionStatus: googleCalendarConnectionState.status.rawValue,
            googleCalendarLastFetchStatus: googleCalendarLastFetchStatus,
            dailyBriefingStatus: dailyBriefing.status.rawValue,
            dailyBriefingCalendarItemCount: dailyBriefing.calendarItems.count,
            dailyBriefingMailItemCount: dailyBriefing.mailItems.count,
            localBriefingItemCount: localBriefing.localBriefingItems.count,
            universalDocumentSkillCount: universalDocumentSkillCount,
            universalDocumentRouteAvailable: universalDocumentRouteAvailable,
            routeResolverAvailable: routeResolverAvailable,
            workflowRunnerAvailable: workflowRunnerAvailable,
            toolExecutionLayerAvailable: toolExecutionLayerAvailable,
            connectorGuardAvailable: connectorGuardAvailable,
            planRunnerAvailable: planRunnerAvailable,
            planRunnerUniversalDocumentEnabled: planRunnerUniversalDocumentEnabled,
            planRunnerFailureReasonAware: planRunnerFailureReasonAware,
            agentPipelineAvailable: agentPipelineAvailable,
            defaultPipelineOrderCount: defaultPipelineOrderCount,
            pipelineContextAvailable: pipelineContextAvailable,
            executionContractAvailable: executionContractAvailable,
            executionContextBagAvailable: executionContextBagAvailable,
            executionVerifierAvailable: executionVerifierAvailable,
            planPipelineContractAligned: planPipelineContractAligned,
            legacyFallbackOutcomeAware: legacyFallbackOutcomeAware,
            fileIntakeAvailable: fileIntakeAvailable,
            fileIntakeReadableExtensions: fileIntakeReadableExtensions,
            fileIntakePlannedExtensions: fileIntakePlannedExtensions,
            fileIntakeMaxFileSizeMB: fileIntakeMaxFileSizeMB,
            lastFileIntakeStatus: lastFileIntakeStatus,
            lastFileIntakeFilename: lastFileIntakeFilename,
            lastFileIntakeHasExtractedText: lastFileIntakeHasExtractedText,
            lastFileIntakeExtractedCharacterCount: lastFileIntakeExtractedCharacterCount,
            fileIntakeToDocumentAvailable: fileIntakeToDocumentAvailable,
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
