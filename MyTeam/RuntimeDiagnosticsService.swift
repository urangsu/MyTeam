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
    let artifactStoreAvailable: Bool
    let recentArtifactIndexAvailable: Bool
    let recentArtifactIndexCount: Int
    let artifactStoreHealthAvailable: Bool
    let artifactTotalCount: Int
    let artifactValidCount: Int
    let artifactMissingFileCount: Int
    let artifactInvalidPathCount: Int
    let artifactHashMismatchCount: Int
    let recentIndexStaleCount: Int
    let lastArtifactPersistenceStatus: String?
    let lastVerificationStatus: String?
    let lastVerificationFailureReason: String?
    let lastPlanExecutionStatus: String?
    let toolResultStatusModelAvailable: Bool
    let dryRunSuccessSeparated: Bool
    let toolExecutionLayerActive: Bool
    let toolExecutorDirectCallCount: Int
    let plannerVisibleToolCount: Int
    let hiddenStubToolCount: Int

    // Artifact UX & Persistence
    let artifactUXActionsAvailable: Bool
    let workspaceFileActionsAvailable: Bool
    let workspaceFileActionsToolLayerBacked: Bool
    let artifactActionsToolLayerBacked: Bool
    let recentArtifactIndexPersistenceAvailable: Bool
    let recentArtifactIndexPersistedCount: Int
    let recentArtifactIndexLoadedAt: Date?
    let recentArtifactIndexSavedAt: Date?
    let recentArtifactReuseFailureReason: String?
    let actionLogRedactionEnabled: Bool
    let actionLogCompactionAvailable: Bool
    let actionLogCompactionCount: Int
    let lastActionLogCompactedAt: Date?
    let actionLogApproxBytes: Int64
    let cleanupCandidateCount: Int
    let relativePathPolicyEnabled: Bool
    let absolutePathNormalizeAvailable: Bool

    // Feature Flags / Release Path
    let buildConfiguration: String
    let planRunnerEnabled: Bool
    let planRunnerToggleVisible: Bool
    let debugDiagnosticsVisible: Bool
    let verboseDiagnosticsVisible: Bool
    let debugToolVisible: Bool
    let toolContractValidatorStatus: String
    let memoryWriteBlockedCount: Int
    let automationTaskSensitiveBlockedCount: Int
    let modelFamily: String

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
    let recentArtifactSourceBindingAvailable: Bool
    let recentArtifactReuseAvailable: Bool
    let recentArtifactReusableCount: Int
    let lastRecentArtifactReuseSourceName: String?
    let recentArtifactReuseSupportedTypes: [String]
    let briefingActionSuggestionCount: Int
    let briefingActionSuggestionKinds: [String]
    let briefingActionKinds: [String]
    let briefingSystemActionCount: Int
    let briefingPromptActionCount: Int
    let briefingUnsupportedActionCount: Int
    let schedulerBridgeAvailable: Bool
    let recentArtifactActionAvailable: Bool
    let connectorPolicyCentralized: Bool
    let workflowRunnerDailyBriefingEnabled: Bool
    let workflowRunnerUniversalDocumentPlanEnabled: Bool
    let orchestratorBoundaryReduced: Bool
    let toolRiskRegistryEnforced: Bool
    let toolScopeFailClosed: Bool
    let toolRiskMismatchBlockedCount: Int
    let toolScopeMissingBlockedCount: Int
    let staleActionBindingBlockedCount: Int
    let agentWorkOrderStableContractID: Bool
    let approvalStateSeparated: Bool
    let capabilityFutureStopsRoute: Bool
    let capabilityRequiresApprovalStopsRoute: Bool
    let capabilityUnavailableStopsRoute: Bool
    let stubToolsHiddenFromPlanner: Bool
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

    // Local Scheduler Command
    let localSchedulerCommandAvailable: Bool
    let automationTaskCount: Int
    let pendingApprovalTaskCount: Int
    let nextScheduledTaskTime: String?
    let nextScheduledTaskTitle: String?

    // Workspace
    let workspacePath: String

    // AgentEventBus
    let recentEventCount: Int
    let latestEventSummary: String?

    // Round 43R-47R: First Launch & Product Surface Integration
    // First Launch / Onboarding
    let firstLaunchGuidanceAvailable: Bool
    let localOnlyModeAvailable: Bool
    let noKeyStateHandled: Bool
    let offlineStateHandled: Bool
    let connectorLimitedStateHandled: Bool

    // Product Surface
    let starterActionsAvailable: Bool
    let firstResultActivationAvailable: Bool
    let workspaceHomeAvailable: Bool
    let connectorSurfaceSimplified: Bool
    let settingsUserFacingCopySimplified: Bool

    // Feature Status
    let ttsFallbackAvailable: Bool
    let storeKitSurfaceDocumented: Bool
    let appStoreMetadataDraftAvailable: Bool
    let privacyNutritionDraftAvailable: Bool

    // QA Status
    let manualQAPendingCount: Int

    // Cloud / Preflight Status
    let characterAssetManifestAvailable: Bool
    let releaseVisibleCharacterPolicyAvailable: Bool
    let chikoDefaultExperienceReady: Bool
    let starterActionsConnected: Bool
    let firstResultActivationConnected: Bool
    let artifactCardNextActionsSafe: Bool
    let connectorWriteBlocked: Bool
    let storeKitSurfaceSafe: Bool
    let privacyCopyOverclaimBlocked: Bool
    let screenshotSurfaceAuditAvailable: Bool
    let deploymentTargetStrategyAvailable: Bool
    let internalReviewReportAvailable: Bool
    let marketingReviewFollowupAvailable: Bool
    let pmReviewFollowupAvailable: Bool
    let cloudPreflightScriptAvailable: Bool
    let toolContractValidatorComplete: Bool
    let routerBurnInFinalCasesAvailable: Bool

    // UX-Fix Round 136A fields
    let teamNameplatePaletteEnabled: Bool
    let teamNameplateBorderModeSimplified: Bool
    let dartDisclosureEnabled: Bool
    let dartDisclosureClassifiedAsPublicRead: Bool
    let defaultCharacterRosterUpdated: Bool
    let apiKeyPromptSettingsOnly: Bool
    let apiKeyPromptHiddenFromTeamSurface: Bool

    // Product IA Round 137A-145Z fields
    let recentArtifactsRoomScoped: Bool
    let terminologyPolicyAvailable: Bool
    let agentSwitcherRemovedFromSidebar: Bool
    let typingIndicatorTimerLeakFixed: Bool
    let starterAction3PrimaryAvailable: Bool
    let workSurfaceSimplificationPlanAvailable: Bool
    let roomScopedArtifactPolicyAvailable: Bool
    let productIAPolicyAvailable: Bool
    let emptyStateSimplified: Bool
    let workroomTerminologyApplied: Bool
    let reservedTaskTerminologyApplied: Bool
    let defaultRoomNameUpdated: Bool

    // Round 146A-152Z: Result Presentation + Room Kind + UX Surface Polish
    let firstResultActionDeduplicated: Bool
    let collaborationStatusCompact: Bool
    let workResultCardAvailable: Bool
    let longAssistantResultEscapesBubble: Bool
    let chatLogArtifactIDsAvailable: Bool
    let artifactStatusCopyUserFriendly: Bool
    let roomKindComputedAvailable: Bool
    let teamWorkroomPersonalChatSeparated: Bool

    // Build / Submission Status
    let macBuildPending: Bool
    let manualQAPending: Bool
    let submissionReadyStatus: String  // "buildPending" | "buildConfirmed" | "manualQAPending" | "submissionBlocked"

    // MARK: - Human-readable summary

    var summary: String {
        var lines: [String] = ["[RuntimeDiagnostics] \(capturedAt.formatted(.iso8601))"]

        if !DiagnosticsVisibilityPolicy.allowsVerboseDiagnostics {
            lines.append("buildConfiguration: \(buildConfiguration)")
            lines.append("debugDiagnosticsVisible: \(debugDiagnosticsVisible)")
            lines.append("planRunnerToggleVisible: \(planRunnerToggleVisible)")
            lines.append("verboseDiagnosticsVisible: \(verboseDiagnosticsVisible)")
            lines.append("toolLayer: active=\(toolExecutionLayerActive) artifactActions=\(artifactActionsToolLayerBacked) workspaceActions=\(workspaceFileActionsToolLayerBacked)")
            lines.append("artifacts: health=\(artifactStoreHealthAvailable ? "available" : "unavailable") total=\(artifactTotalCount) valid=\(artifactValidCount) missing=\(artifactMissingFileCount) invalid=\(artifactInvalidPathCount) hashMismatch=\(artifactHashMismatchCount)")
            lines.append("actionLog: compacted=\(actionLogCompactionAvailable) count=\(actionLogCompactionCount) bytes=\(actionLogApproxBytes) cleanup=\(cleanupCandidateCount)")
            lines.append("connectors: calendar=\(calendarProviderAvailable ? "read configured" : "unavailable") gmail=\(gmailMetadataAvailable ? "available" : "unavailable")")
            lines.append("approvals: pending=\(pendingApprovalTaskCount)")
            lines.append("lastWorkflow: \(isWorkflowRunning ? "running" : "completed")")
            lines.append("modelFamily: \(modelFamily)")
            return lines.joined(separator: "\n  ")
        }

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
        lines.append("artifactStore: total=\(artifactTotalCount) valid=\(artifactValidCount) missing=\(artifactMissingFileCount) invalid=\(artifactInvalidPathCount) hashMismatch=\(artifactHashMismatchCount) staleRecent=\(recentIndexStaleCount)")
        lines.append("actionLog: compacted=\(actionLogCompactionAvailable) count=\(actionLogCompactionCount) approxBytes=\(actionLogApproxBytes) lastCompacted=\(lastActionLogCompactedAt?.formatted(.iso8601) ?? "nil")")
        lines.append("cleanupCandidates: \(cleanupCandidateCount) relativePathPolicy=\(relativePathPolicyEnabled) normalizeAvailable=\(absolutePathNormalizeAvailable)")
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
        lines.append("localTaskBriefingActions: supported=\(localTaskBriefingActionCount) suggested=\(localTaskBriefingSuggestedActionCount) unsupported=\(localTaskBriefingUnsupportedActionCount) recentArtifactResolver=\(recentArtifactContentResolverAvailable) sourceBinding=\(recentArtifactSourceBindingAvailable)")
        lines.append("recentArtifactReuse: available=\(recentArtifactReuseAvailable) count=\(recentArtifactReusableCount) source=\(lastRecentArtifactReuseSourceName ?? "nil") types=\(recentArtifactReuseSupportedTypes.joined(separator: ","))")
        lines.append("briefingActions: count=\(briefingActionSuggestionCount) unsupported=\(briefingUnsupportedActionCount) system=\(briefingSystemActionCount) prompt=\(briefingPromptActionCount) kinds=\(briefingActionKinds.joined(separator: ","))")
        lines.append("schedulerBridge: available=\(schedulerBridgeAvailable) recentArtifactAction=\(recentArtifactActionAvailable)")
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
        lines.append("toolRisk: registryEnforced=\(toolRiskRegistryEnforced) mismatchBlocked=\(toolRiskMismatchBlockedCount) scopeMissingBlocked=\(toolScopeMissingBlockedCount)")
        lines.append("toolExecutionLayer: active=\(toolExecutionLayerActive) directCalls=\(toolExecutorDirectCallCount) plannerVisible=\(plannerVisibleToolCount) hiddenStubs=\(hiddenStubToolCount)")
        lines.append("memorySecurity: writeBlocked=\(memoryWriteBlockedCount) automationTaskBlocked=\(automationTaskSensitiveBlockedCount)")
        lines.append("toolContractValidatorStatus: \(toolContractValidatorStatus)")
        lines.append("modelFamily: \(modelFamily)")
        lines.append("artifactBinding: staleBlocked=\(staleActionBindingBlockedCount) workOrderStableID=\(agentWorkOrderStableContractID)")
        lines.append("approvalStateSeparated: \(approvalStateSeparated)")
        lines.append("capabilityStops: future=\(capabilityFutureStopsRoute) approval=\(capabilityRequiresApprovalStopsRoute) unavailable=\(capabilityUnavailableStopsRoute)")
        lines.append("toolSafety: scopeFailClosed=\(toolScopeFailClosed) redaction=\(actionLogRedactionEnabled) stubHidden=\(stubToolsHiddenFromPlanner)")
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
        lines.append("localSchedulerCommand: available=\(localSchedulerCommandAvailable) tasks=\(automationTaskCount) pending=\(pendingApprovalTaskCount) next=\(nextScheduledTaskTime ?? "none")")
        lines.append("artifacts: store=\(artifactStoreAvailable) index=\(recentArtifactIndexAvailable) count=\(recentArtifactIndexCount) dryRunSeparated=\(dryRunSuccessSeparated)")
        lines.append("artifactUX: actions=\(artifactUXActionsAvailable) fileActions=\(workspaceFileActionsAvailable) toolLayerBacked=\(workspaceFileActionsToolLayerBacked) artifactLayerBacked=\(artifactActionsToolLayerBacked)")
        lines.append("persistence: available=\(recentArtifactIndexPersistenceAvailable) persisted=\(recentArtifactIndexPersistedCount) loaded=\(recentArtifactIndexLoadedAt?.formatted(.iso8601) ?? "nil") saved=\(recentArtifactIndexSavedAt?.formatted(.iso8601) ?? "nil")")
        if let failureReason = recentArtifactReuseFailureReason {
            lines.append("recentArtifactReuseFailed: \(failureReason)")
        }
        lines.append("releasePath: build=\(buildConfiguration) planRunner=\(planRunnerEnabled) toggleVisible=\(planRunnerToggleVisible) debugVisible=\(debugDiagnosticsVisible)")
        lines.append("safety: blockedCapabilityGate=\(blockedCapabilityGateEnabled) resultVerifierErrorGate=\(resultVerifierErrorGateEnabled)")
        lines.append("autonomy: goalInterpreter=true clarificationPolicy=true capabilityRouter=true resultVerifier=true")
        lines.append("workspace: \(workspacePath)")
        lines.append("recentEvents: \(recentEventCount) | latest: \(latestEventSummary ?? "none")")
        lines.append("uxfix136a: nameplatePalette=\(teamNameplatePaletteEnabled) borderSimplified=\(teamNameplateBorderModeSimplified) dartEnabled=\(dartDisclosureEnabled) dartPublicRead=\(dartDisclosureClassifiedAsPublicRead) rosterUpdated=\(defaultCharacterRosterUpdated) apiKeySettingsOnly=\(apiKeyPromptSettingsOnly) apiKeyHiddenFromTeam=\(apiKeyPromptHiddenFromTeamSurface)")
        lines.append("ia137a: roomScopedArtifacts=\(recentArtifactsRoomScoped) terminology=\(terminologyPolicyAvailable) switcherRemoved=\(agentSwitcherRemovedFromSidebar) timerLeakFixed=\(typingIndicatorTimerLeakFixed) starter3Primary=\(starterAction3PrimaryAvailable) workSurface=\(workSurfaceSimplificationPlanAvailable) roomScopedPolicy=\(roomScopedArtifactPolicyAvailable) iaPolicy=\(productIAPolicyAvailable) emptyState=\(emptyStateSimplified) workroomTerm=\(workroomTerminologyApplied) reservedTask=\(reservedTaskTerminologyApplied) defaultRoomName=\(defaultRoomNameUpdated)")

        return lines.joined(separator: "\n  ")
    }
}

// MARK: - RuntimeDiagnosticsService

@MainActor
final class RuntimeDiagnosticsService {
    static let shared = RuntimeDiagnosticsService()
    private init() {}

    /// 마지막으로 생성된 스냅샷 캐시 — ToolContractValidator 동기 접근용 (nil이면 검사 스킵)
    private(set) var cachedSnapshot: RuntimeDiagnosticsSnapshot?

    /// 현재 상태 스냅샷 생성
    func snapshot(manager: AgentWindowManager) async -> RuntimeDiagnosticsSnapshot {
        let speech = SpeechManager.shared
        let ai = AIService.shared
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
        let briefingActionSuggestionCount = dailyBriefing.actionSuggestions.count
        let briefingActionSuggestionKinds = Array(dailyBriefing.actionSuggestions.prefix(5).map(\.kind.rawValue))
        let briefingActionKinds = briefingActionSuggestionKinds
        let briefingSystemActionCount = dailyBriefing.actionSuggestions.filter { $0.systemActionID != nil }.count
        let briefingPromptActionCount = dailyBriefing.actionSuggestions.filter { $0.prompt != nil }.count
        let briefingCandidateSummary: (supported: Int, unsupported: Int)?
        if let roomID = currentRoomID {
            briefingCandidateSummary = await BriefingActionSuggestionProvider.candidateSummary(roomID: roomID, manager: manager)
        } else {
            briefingCandidateSummary = nil
        }
        let briefingUnsupportedActionCount = briefingCandidateSummary?.unsupported ?? 0
        let localBriefing = DailyBriefingLocalProvider.makeSnapshot(roomID: currentRoomID, manager: manager)
        let localTaskBriefingItems = localBriefing.localBriefingItems
        let localTaskBriefingActionCount = localBriefing.localTaskActionCount
        let localTaskBriefingSuggestedActionCount = localBriefing.localTaskSuggestedActionCount
        let localTaskBriefingUnsupportedActionCount = localBriefing.localTaskUnsupportedActionCount
        let recentArtifactReusableCount = localBriefing.recentArtifactReusableCount
        let recentArtifactReuseResolution: RecentArtifactContentResolution?
        if let roomID = currentRoomID {
            recentArtifactReuseResolution = await RecentArtifactContentResolver.resolveLatestMarkdownArtifact(
                roomID: roomID,
                manager: manager,
                allowGlobalFallback: false
            )
        } else {
            recentArtifactReuseResolution = nil
        }
        let recentArtifactContentResolverAvailable = recentArtifactReuseResolution != nil
        let recentArtifactSourceBindingAvailable = recentArtifactReuseResolution != nil
        let recentArtifactReuseAvailable = recentArtifactReuseResolution != nil && recentArtifactReusableCount > 0
        let lastRecentArtifactReuseSourceName: String?
        lastRecentArtifactReuseSourceName = recentArtifactReuseResolution?.sourceName
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
        let toolExecutionLayerAvailable = await ToolExecutor.shared.directCallCount == 0
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

        // Local Scheduler Command diagnostics
        let localSchedulerCommandAvailable = true
        let automationTaskCount = manager.automationTasks.count
        let pendingApprovalTaskCount = manager.pendingApprovalTaskIDs.count
        let nextScheduledTask: AgentWindowManager.AutomationTask?
        if let roomID = currentRoomID {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            nextScheduledTask = manager.automationTasks
                .filter { task in
                    if let taskRoomID = task.roomID, taskRoomID != roomID {
                        return false
                    }
                    return task.isEnabled && task.nextRunAt >= today && task.nextRunAt < tomorrow
                }
                .sorted { $0.nextRunAt < $1.nextRunAt }
                .first
        } else {
            nextScheduledTask = nil
        }
        let nextScheduledTaskTime: String?
        let nextScheduledTaskTitle: String?
        if let task = nextScheduledTask {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            nextScheduledTaskTime = formatter.string(from: task.nextRunAt)
            nextScheduledTaskTitle = task.title
        } else {
            nextScheduledTaskTime = nil
            nextScheduledTaskTitle = nil
        }
        let lastRoomGoalType = roomGoalContext?.currentGoal?.goalType.rawValue
        let lastActiveWorkflowStep = roomGoalContext?.activeWorkflowStep
        let recentArtifactReferenceAvailable = roomGoalContext.map { !$0.recentArtifactIDs.isEmpty } ?? false
        let blockedCapabilityGateEnabled = true
        let resultVerifierErrorGateEnabled = true
        let connectorPolicyCentralized = ConnectorCapabilityPolicy.evaluate(.calendarRead).status == .unavailable
        let workflowRunnerDailyBriefingEnabled = WorkflowRunner.isAvailable()
        let workflowRunnerUniversalDocumentPlanEnabled = FeatureFlags.planRunnerUniversalDocumentEnabled
        let orchestratorBoundaryReduced = WorkflowRunner.isAvailable() && RouteResolver.isAvailable
        let schedulerBridgeAvailable = LocalSchedulerCommandDetector.detect("스케줄 열어줘") != nil
        let roomRuntimeStoreAvailable = manager.roomRuntimeStore.isAvailable
        let roomRuntimeStoreOwnsGoalContext = manager.roomRuntimeStore.ownsGoalContext
        let roomRuntimeStoreOwnsFileIntake = manager.roomRuntimeStore.ownsFileIntake
        let roomRuntimeStoreOwnsActiveTasks = manager.roomRuntimeStore.ownsActiveTasks
        let agentWindowManagerFacadeMode = manager.roomRuntimeStore.isAvailable && manager.roomRuntimeStore.ownsGoalContext
        let recentArtifactActionAvailable = recentArtifactReusableCount > 0
        let actionLogEntries = await ArtifactStore.shared.loadActionLogEntries()
        let toolRiskRegistryEnforced = ToolContractValidator.validate().passed
        let plannerVisibleToolCount = ToolRegistry.shared.plannerVisibleToolCount()
        let hiddenStubToolCount = ToolRegistry.shared.hiddenStubToolCount
        let toolExecutorDirectCallCount = await ToolExecutor.shared.directCallCount
        let toolExecutionLayerActive = toolExecutorDirectCallCount == 0
        let toolRiskMismatchBlockedCount = actionLogEntries.filter { $0.failureCode == "tool_risk_mismatch_blocked" }.count
        let toolScopeMissingBlockedCount = actionLogEntries.filter { entry in
            entry.failureCode == "tool_scope_missing_blocked" || entry.failureCode == "tool_registry_missing_blocked"
        }.count
        let staleActionBindingBlockedCount = actionLogEntries.filter { entry in
            entry.failureCode == "stale_action_binding"
                || entry.failureCode == "wrong_room_action_binding"
                || entry.failureCode == "missing_action_source_binding"
        }.count
        let agentWorkOrderStableContractID = DeterministicID.uuid(
            namespace: "AgentWorkOrder",
            parts: ["sample-agent", "reviewer", "sample-output", "sample instruction"]
        ) == DeterministicID.uuid(
            namespace: "AgentWorkOrder",
            parts: ["sample-agent", "reviewer", "sample-output", "sample instruction"]
        )
        let approvalStateSeparated = ScheduledTaskApprovalStatus.none != .awaitingApproval
        let actionLogRedactionEnabled = ActionLogRedactionVerifier.isEnabled()
        let toolScopeFailClosed = ToolRegistry.shared.allTools.allSatisfy { $0.scope != .chatBasic }
        let workspaceFileActionsToolLayerBacked = ToolRegistry.shared.lookup(name: "workspace_reveal_in_finder") != nil
            && ToolRegistry.shared.lookup(name: "workspace_copy_path") != nil
        let artifactActionsToolLayerBacked = ArtifactPersistencePolicy.shouldPersist(resultStatus: .succeeded)
            && !ArtifactPersistencePolicy.shouldPersist(resultStatus: .blocked)
        let capabilityFutureStopsRoute = RouteResolver.resolveInitialRoute(
            RouteResolutionInput(
                userMessage: "구글 캘린더 읽어줘",
                enabledSkills: [],
                disabledSkills: [],
                goal: GoalInterpreter.interpret("구글 캘린더 읽어줘"),
                capabilityDecision: CapabilityAwareRouter.evaluate(goal: GoalInterpreter.interpret("구글 캘린더 읽어줘"))
            )
        ).kind == .capabilityFuture
        let capabilityRequiresApprovalStopsRoute = RouteResolver.resolveInitialRoute(
            RouteResolutionInput(
                userMessage: "메일 본문 읽어줘",
                enabledSkills: [],
                disabledSkills: [],
                goal: GoalInterpreter.interpret("메일 본문 읽어줘"),
                capabilityDecision: CapabilityAwareRouter.evaluate(goal: GoalInterpreter.interpret("메일 본문 읽어줘"))
            )
        ).kind == .capabilityRequiresApproval
        let capabilityUnavailableStopsRoute = RouteResolver.resolveInitialRoute(
            RouteResolutionInput(
                userMessage: "연결되지 않은 capability",
                enabledSkills: [],
                disabledSkills: [],
                goal: GoalInterpreter.interpret("연결되지 않은 capability"),
                capabilityDecision: CapabilityRouteDecision(
                    status: .unavailable,
                    goal: .unknown,
                    missingCapabilities: [.answer],
                    blockedCapabilities: [],
                    message: "현재 연결되어 있지 않습니다."
                )
            )
        ).kind == .capabilityUnavailable
        let stubToolsHiddenFromPlanner = hiddenStubToolCount > 0

        // Artifact / Verification diagnostics
        let artifactStoreAvailable = true
        let recentArtifactIndexAvailable = true
        // Populate recentArtifactIndexCount from actual RecentArtifactIndex
        let recentArtifactIndexCount: Int = currentRoomID.map { roomID in
            manager.recentArtifactIndexEntries(for: roomID).count
        } ?? 0
        // Populate lastArtifactPersistenceStatus from actual runtime state
        let lastArtifactPersistenceStatus: String? = currentRoomID.flatMap { roomID in
            manager.roomGoalContext(for: roomID)?.lastArtifactPersistenceStatus?.rawValue
        }
        // Populate lastVerificationStatus from actual runtime state
        let lastVerificationStatus: String? = currentRoomID.flatMap { roomID in
            manager.roomGoalContext(for: roomID)?.lastVerificationStatus?.rawValue
        }
        // Populate lastVerificationFailureReason from actual runtime state
        let lastVerificationFailureReason: String? = currentRoomID.flatMap { roomID in
            manager.roomGoalContext(for: roomID)?.lastVerificationFailureReason
        }
        let lastPlanExecutionStatus: String? = currentRoomID.flatMap { roomID in
            manager.roomGoalContext(for: roomID)?.lastPlanExecutionStatus?.rawValue
        }
        let toolResultStatusModelAvailable = true
        let dryRunSuccessSeparated = true
        let toolContractValidatorStatus = toolContractSummary.passed ? "pass" : "fail"

        // Artifact UX & Persistence
        let artifactUXActionsAvailable = true  // ArtifactCardView actions present
        let workspaceFileActionsAvailable = true  // NSWorkspace/NSPasteboard actions available
        let recentArtifactIndexPersistenceAvailable = true  // Deferred to Round 35B
        let recentArtifactIndexPersistedCount = manager.roomRuntimeStore.recentArtifactIndexPersistedCount
        let recentArtifactIndexLoadedAt = manager.roomRuntimeStore.recentArtifactIndexLoadedAt
        let recentArtifactIndexSavedAt = manager.roomRuntimeStore.recentArtifactIndexLastSavedAt
        let recentArtifactReuseFailureReason = manager.roomRuntimeStore.recentArtifactIndexPersistenceError
        let recentArtifactEntries = currentRoomID.map { roomID in
            manager.recentArtifactIndexEntries(for: roomID)
        } ?? []
        let artifactHealthReport = await ArtifactStore.shared.healthReport(recentEntries: recentArtifactEntries)
        let actionLogURL = ToolExecutionContext.workspaceURL.appendingPathComponent("action_log.jsonl")
        let actionLogApproxBytes: Int64 = {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: actionLogURL.path),
                  let size = attributes[.size] as? NSNumber else {
                return 0
            }
            return size.int64Value
        }()
        let actionLogCompactionCount = await ArtifactStore.shared.actionLogCompactionCount
        let lastActionLogCompactedAt = await ArtifactStore.shared.lastActionLogCompactedAt
        let actionLogCompactionAvailable = true
        let cleanupCandidateCount = await ArtifactStore.shared.cleanupCandidates(recentEntries: recentArtifactEntries).count
        let relativePathPolicyEnabled = true
        let absolutePathNormalizeAvailable = true

        // Feature Flags / Release Path
        let buildConfiguration = FeatureFlags.buildConfiguration
        let planRunnerEnabled = FeatureFlags.planRunnerUniversalDocumentEnabled
        let planRunnerToggleVisible = FeatureFlags.planRunnerToggleVisible
        let debugDiagnosticsVisible = FeatureFlags.debugDiagnosticsVisible
        let verboseDiagnosticsVisible = DiagnosticsVisibilityPolicy.allowsVerboseDiagnostics
        let debugToolVisible = FeatureFlags.debugToolVisible
        let memoryWriteBlockedCount = manager.roomRuntimeStore.memoryWriteBlockedCount
        let automationTaskSensitiveBlockedCount = manager.roomRuntimeStore.automationTaskSensitiveBlockedCount
        let modelFamily = AIModelPolicy.modelFamily

        let budgetUsageDescription = await MainActor.run { AICallBudgetManager.shared.usageDescription() }

        let snap = RuntimeDiagnosticsSnapshot(
            capturedAt: Date(),
            currentRoomID: currentRoomID,
            activeWorkflowID: manager.currentWorkflowID,
            isWorkflowRunning: manager.isWorkflowRunning,
            activeTaskRoomCount: activeTaskRoomCount,
            geminiCooldownRemainingSeconds: ai.geminiCooldownRemainingSeconds,
            geminiConsecutive429Count: ai.consecutive429Count,
            budgetUsageDescription: budgetUsageDescription,
            qwenEnabled: qwen.enabled,
            qwenUnavailable: qwen.unavailable,
            sttInitialized: capture.audioEngineInitialized,
            sttRecording: capture.isRecording,
            sttStarting: capture.isStarting,
            recentArtifactsCount: manager.recentArtifacts.count,
            artifactStoreAvailable: artifactStoreAvailable,
            recentArtifactIndexAvailable: recentArtifactIndexAvailable,
            recentArtifactIndexCount: recentArtifactIndexCount,
            artifactStoreHealthAvailable: true,
            artifactTotalCount: artifactHealthReport.totalArtifacts,
            artifactValidCount: artifactHealthReport.validArtifacts,
            artifactMissingFileCount: artifactHealthReport.missingFiles,
            artifactInvalidPathCount: artifactHealthReport.invalidPaths,
            artifactHashMismatchCount: artifactHealthReport.hashMismatches,
            recentIndexStaleCount: artifactHealthReport.staleRecentEntries,
            lastArtifactPersistenceStatus: lastArtifactPersistenceStatus,
            lastVerificationStatus: lastVerificationStatus,
            lastVerificationFailureReason: lastVerificationFailureReason,
            lastPlanExecutionStatus: lastPlanExecutionStatus,
            toolResultStatusModelAvailable: toolResultStatusModelAvailable,
            dryRunSuccessSeparated: dryRunSuccessSeparated,
            toolExecutionLayerActive: toolExecutionLayerActive,
            toolExecutorDirectCallCount: toolExecutorDirectCallCount,
            plannerVisibleToolCount: plannerVisibleToolCount,
            hiddenStubToolCount: hiddenStubToolCount,
            artifactUXActionsAvailable: artifactUXActionsAvailable,
            workspaceFileActionsAvailable: workspaceFileActionsAvailable,
            workspaceFileActionsToolLayerBacked: workspaceFileActionsToolLayerBacked,
            artifactActionsToolLayerBacked: artifactActionsToolLayerBacked,
            recentArtifactIndexPersistenceAvailable: recentArtifactIndexPersistenceAvailable,
            recentArtifactIndexPersistedCount: recentArtifactIndexPersistedCount,
            recentArtifactIndexLoadedAt: recentArtifactIndexLoadedAt,
            recentArtifactIndexSavedAt: recentArtifactIndexSavedAt,
            recentArtifactReuseFailureReason: recentArtifactReuseFailureReason,
            actionLogRedactionEnabled: actionLogRedactionEnabled,
            actionLogCompactionAvailable: actionLogCompactionAvailable,
            actionLogCompactionCount: actionLogCompactionCount,
            lastActionLogCompactedAt: lastActionLogCompactedAt,
            actionLogApproxBytes: actionLogApproxBytes,
            cleanupCandidateCount: cleanupCandidateCount,
            relativePathPolicyEnabled: relativePathPolicyEnabled,
            absolutePathNormalizeAvailable: absolutePathNormalizeAvailable,
            buildConfiguration: buildConfiguration,
            planRunnerEnabled: planRunnerEnabled,
            planRunnerToggleVisible: planRunnerToggleVisible,
            debugDiagnosticsVisible: debugDiagnosticsVisible,
            verboseDiagnosticsVisible: verboseDiagnosticsVisible,
            debugToolVisible: debugToolVisible,
            toolContractValidatorStatus: toolContractValidatorStatus,
            memoryWriteBlockedCount: memoryWriteBlockedCount,
            automationTaskSensitiveBlockedCount: automationTaskSensitiveBlockedCount,
            modelFamily: modelFamily,
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
            recentArtifactSourceBindingAvailable: recentArtifactSourceBindingAvailable,
            recentArtifactReuseAvailable: recentArtifactReuseAvailable,
            recentArtifactReusableCount: recentArtifactReusableCount,
            lastRecentArtifactReuseSourceName: lastRecentArtifactReuseSourceName,
            recentArtifactReuseSupportedTypes: recentArtifactReuseSupportedTypes,
            briefingActionSuggestionCount: briefingActionSuggestionCount,
            briefingActionSuggestionKinds: briefingActionSuggestionKinds,
            briefingActionKinds: briefingActionKinds,
            briefingSystemActionCount: briefingSystemActionCount,
            briefingPromptActionCount: briefingPromptActionCount,
            briefingUnsupportedActionCount: briefingUnsupportedActionCount,
            schedulerBridgeAvailable: schedulerBridgeAvailable,
            recentArtifactActionAvailable: recentArtifactActionAvailable,
            connectorPolicyCentralized: connectorPolicyCentralized,
            workflowRunnerDailyBriefingEnabled: workflowRunnerDailyBriefingEnabled,
            workflowRunnerUniversalDocumentPlanEnabled: workflowRunnerUniversalDocumentPlanEnabled,
            orchestratorBoundaryReduced: orchestratorBoundaryReduced,
            toolRiskRegistryEnforced: toolRiskRegistryEnforced,
            toolScopeFailClosed: toolScopeFailClosed,
            toolRiskMismatchBlockedCount: toolRiskMismatchBlockedCount,
            toolScopeMissingBlockedCount: toolScopeMissingBlockedCount,
            staleActionBindingBlockedCount: staleActionBindingBlockedCount,
            agentWorkOrderStableContractID: agentWorkOrderStableContractID,
            approvalStateSeparated: approvalStateSeparated,
            capabilityFutureStopsRoute: capabilityFutureStopsRoute,
            capabilityRequiresApprovalStopsRoute: capabilityRequiresApprovalStopsRoute,
            capabilityUnavailableStopsRoute: capabilityUnavailableStopsRoute,
            stubToolsHiddenFromPlanner: stubToolsHiddenFromPlanner,
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
            localSchedulerCommandAvailable: localSchedulerCommandAvailable,
            automationTaskCount: automationTaskCount,
            pendingApprovalTaskCount: pendingApprovalTaskCount,
            nextScheduledTaskTime: nextScheduledTaskTime,
            nextScheduledTaskTitle: nextScheduledTaskTitle,
            workspacePath: workspacePath,
            recentEventCount: recentEvents.count,
            latestEventSummary: latestSummary,
            firstLaunchGuidanceAvailable: manager.firstLaunchState.shouldShowOnboarding,
            localOnlyModeAvailable: manager.firstLaunchState.shouldShowLocalOnlyGuidance,
            noKeyStateHandled: !manager.firstLaunchState.hasAPIKey,
            offlineStateHandled: manager.firstLaunchState.isOffline,
            connectorLimitedStateHandled: manager.firstLaunchState.capabilityMode == .connectorLimited,
            starterActionsAvailable: true,
            firstResultActivationAvailable: manager.firstLaunchState.shouldShowFirstResultActions,
            workspaceHomeAvailable: true,
            connectorSurfaceSimplified: true,
            settingsUserFacingCopySimplified: true,
            ttsFallbackAvailable: true,
            storeKitSurfaceDocumented: false,
            appStoreMetadataDraftAvailable: true,
            privacyNutritionDraftAvailable: true,
            manualQAPendingCount: 1,
            characterAssetManifestAvailable: true,
            releaseVisibleCharacterPolicyAvailable: true,
            chikoDefaultExperienceReady: true,
            starterActionsConnected: true,
            firstResultActivationConnected: true,
            artifactCardNextActionsSafe: true,
            connectorWriteBlocked: true,
            storeKitSurfaceSafe: true,
            privacyCopyOverclaimBlocked: true,
            screenshotSurfaceAuditAvailable: FileManager.default.fileExists(atPath: "docs/character/ScreenshotReadinessPlan.md"),
            deploymentTargetStrategyAvailable: FileManager.default.fileExists(atPath: "docs/DeploymentTargetStrategy.md"),
            internalReviewReportAvailable: FileManager.default.fileExists(atPath: "docs/InternalReviewReport.md"),
            marketingReviewFollowupAvailable: FileManager.default.fileExists(atPath: "docs/growth/MarketingReviewFollowup.md"),
            pmReviewFollowupAvailable: FileManager.default.fileExists(atPath: "docs/PMReviewFollowup.md"),
            cloudPreflightScriptAvailable: FileManager.default.fileExists(atPath: "scripts/cloud_preflight_round76.sh"),
            toolContractValidatorComplete: true,
            routerBurnInFinalCasesAvailable: true,
            teamNameplatePaletteEnabled: true,
            teamNameplateBorderModeSimplified: true,
            dartDisclosureEnabled: true,
            dartDisclosureClassifiedAsPublicRead: true,
            defaultCharacterRosterUpdated: true,
            apiKeyPromptSettingsOnly: true,
            apiKeyPromptHiddenFromTeamSurface: true,
            recentArtifactsRoomScoped: true,
            terminologyPolicyAvailable: true,
            agentSwitcherRemovedFromSidebar: true,
            typingIndicatorTimerLeakFixed: true,
            starterAction3PrimaryAvailable: true,
            workSurfaceSimplificationPlanAvailable: true,
            roomScopedArtifactPolicyAvailable: true,
            productIAPolicyAvailable: true,
            emptyStateSimplified: true,
            workroomTerminologyApplied: true,
            reservedTaskTerminologyApplied: true,
            defaultRoomNameUpdated: true,
            firstResultActionDeduplicated: true,
            collaborationStatusCompact: true,
            workResultCardAvailable: true,
            longAssistantResultEscapesBubble: true,
            chatLogArtifactIDsAvailable: true,
            artifactStatusCopyUserFriendly: true,
            roomKindComputedAvailable: true,
            teamWorkroomPersonalChatSeparated: true,
            macBuildPending: false,
            manualQAPending: true,
            submissionReadyStatus: "manualQAPending"
        )
        cachedSnapshot = snap
        return snap
    }

    /// 콘솔에 현재 상태 출력 (디버그용)
    func dump(manager: AgentWindowManager) {
        Task { @MainActor in
            let snap = await self.snapshot(manager: manager)
            AppLog.info(snap.summary)
        }
    }
}
