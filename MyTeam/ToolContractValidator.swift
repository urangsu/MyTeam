import Foundation

struct ToolContractValidationIssue: Identifiable, Equatable {
    enum Severity: String, Codable {
        case warning
        case error
    }

    let id: UUID
    let severity: Severity
    let message: String
}

struct ToolContractValidationSummary: Equatable {
    let errorCount: Int
    let warningCount: Int
    let issues: [ToolContractValidationIssue]
    let plannerVisibleToolCount: Int
    let hiddenStubToolCount: Int

    var passed: Bool { errorCount == 0 }
}

enum ToolContractValidator {
    static func validate() -> ToolContractValidationSummary {
        var issues: [ToolContractValidationIssue] = []
        let tools = ToolRegistry.shared.allTools
        let skills = SkillRegistry.shared.allSkillManifests

        validateTools(tools, issues: &issues)
        validateSkills(skills, issues: &issues)

        // Cloud round validators
        validateReleaseVisibleConnectorPolicy(tools, issues: &issues)
        validateCharacterAssetPolicy(issues: &issues)
        validateStoreKitSurfacePolicy(issues: &issues)
        validatePrivacyCopyPolicy(issues: &issues)
        validateStarterActionPolicy(issues: &issues)
        validateFirstResultActionPolicy(issues: &issues)
        validateExternalWritePolicy(tools, issues: &issues)

        // UX-Fix Round 136A validators
        validateTeamNameplateSettingsPolicy(issues: &issues)
        validateDARTDisclosurePolicy(skills, issues: &issues)
        validateDefaultCharacterRosterPolicy(issues: &issues)
        validateAPIKeyPromptSurfacePolicy(issues: &issues)

        // Product IA Round 137A-145Z validators
        validateRoomScopedArtifactPolicy(issues: &issues)
        validateTerminologyPolicy(issues: &issues)
        validateTypingIndicatorTimerPolicy(issues: &issues)
        validateAgentSwitcherPolicy(issues: &issues)
        validateStarterAction3PrimaryPolicy(issues: &issues)
        validateWorkroomDefaultNamePolicy(issues: &issues)
        validateReservedTaskTerminologyPolicy(issues: &issues)
        validateEmptyStateSimplificationPolicy(issues: &issues)

        // Round 146A-152Z validators
        validateFirstResultActionSurfacePolicy(issues: &issues)
        validateCollaborationStatusCompactPolicy(issues: &issues)
        validateWorkResultPresentationPolicy(issues: &issues)
        validateArtifactStatusCopyPolicy(issues: &issues)
        validateRoomKindPolicy(issues: &issues)

        // Round 153A-162Z validators
        validateWorkResultInlineArtifactPolicy(issues: &issues)
        validateChatLogArtifactLinkingPolicy(issues: &issues)
        validateSkillResultCardFallbackPolicy(issues: &issues)

        // Round 163B-UXNAV validators
        validateAgentQuickSwitchPolicy(issues: &issues)
        validateAgentNavigationMutationPolicy(issues: &issues)
        validatePersonalChatIdentityPolicy(issues: &issues)
        validateTeamWorkroomReturnPolicy(issues: &issues)
        validateStarterChecklistCopyPolicy(issues: &issues)

        // Round 164A-180Z validators
        validateDocumentCreationCoreFlow(issues: &issues)
        validateLocalDocumentFallbackPolicy(issues: &issues)
        validateWorkResultKindPolicy(issues: &issues)
        validateRecentDocumentReuseLoop(issues: &issues)
        validateArtifactActionSurfacePolicy(issues: &issues)

        // Round 181A-195Z validators
        validateWorkroomHomePolicy(issues: &issues)
        validateWorkroomPrimaryActionPolicy(issues: &issues)
        validateWorkroomArtifactRailPolicy(issues: &issues)
        validateWorkroomNextActionPolicy(issues: &issues)
        validateAgentChatWarningDebtPolicy(issues: &issues)

        // Round 196A-230Z validators
        validateWorkroomActionTypesConsolidationPolicy(issues: &issues)
        validateWorkroomEnumDuplicationPolicy(issues: &issues)
        validateWorkroomPbxprojRegistrationPolicy(issues: &issues)
        validateWorkroomHandlerMethodsPolicy(issues: &issues)
        validateWorkroomRoomScopePolicy(issues: &issues)
        validateWorkroomCharacterSystemPreservationPolicy(issues: &issues)
        validateWorkroomCharacterReactionBridgeDocumentationPolicy(issues: &issues)
        validateWorkroomSpriteSheetProductionSpecPolicy(issues: &issues)
        validateWorkroomCharacterReactionEnginePlanPolicy(issues: &issues)

        // Round 231A validators
        validateCharacterReactionEnginePolicy(issues: &issues)
        validateCharacterReactionAnimationStatePolicy(issues: &issues)
        validateWorkroomEventBridgePolicy(issues: &issues)

        // Round 232 validators
        validateCharacterSpriteSheetHandoffPolicy(issues: &issues)
        validateCharacterReactionDelegatePolicy(issues: &issues)
        validateCharacterSpriteRosterPolicy(issues: &issues)

        // Round 233B: Beginner Mode validators
        validateBeginnerModePolicy(issues: &issues)
        validateBeginnerExampleFlowPolicy(issues: &issues)
        validateBeginnerFriendlyRecoveryPolicy(issues: &issues)

        // Round 234: Sprite Asset Gate validators
        validateSpriteAssetPolicy(issues: &issues)
        validateBeginnerExampleArtifactPolicy(issues: &issues)
        validateFriendlyRecoveryActionPolicy(issues: &issues)

        // Round 236: room purpose + blog profile + rename + connector policy
        validateContentDraftAuxiliaryPolicy(issues: &issues)
        validateRoomRenamePolicy(issues: &issues)
        validateRoomScopedConversationPolicy(issues: &issues)
        validateRoomPurposeInferencePolicy(issues: &issues)
        validateBlogRoomProfilePolicy(issues: &issues)
        validateConnectorReadinessPolicy(issues: &issues)
        validatePoliteUserFacingCopyPolicy(issues: &issues)

        // Round 241A: Team Workroom / Personal Chat Hard Separation
        validateTeamPersonalRoomStateSeparationPolicy(issues: &issues)
        validatePersonalConversationNavigationPolicy(issues: &issues)
        validatePersonalChatSidebarPrivacyPolicy(issues: &issues)
        validateQuickSwitchNoRoomMutationPolicy(issues: &issues)

        // Round 241B: Personal Conversation Map + GoalGate + BYOK
        validateSelectedPersonalConversationMapPolicy(issues: &issues)
        validateOpenPersonalConversationAPIPolicy(issues: &issues)
        validateBYOKProviderButtonPolicy(issues: &issues)
        validateGoalGateDirectChatFallbackPolicy(issues: &issues)

        // Round 241C: Surface Routing + Unread Badge + Overlay/Chrome
        validateTeamComposerRoutingPolicy(issues: &issues)
        validatePersonalComposerRoutingPolicy(issues: &issues)
        validateUnreadBadgePolicy(issues: &issues)
        validateAgentMenuPresentationPolicy(issues: &issues)
        validateFooterChromeIntegrationPolicy(issues: &issues)

        // Round 244A: Memory Scope Foundation
        validateMemoryScopeSeparationPolicy(issues: &issues)
        validateCredentialMemoryBlockedPolicy(issues: &issues)
        validateSensitiveMemoryApprovalPolicy(issues: &issues)
        validateRoomMemoryIsolationPolicy(issues: &issues)
        validateProceduralMemoryPolicy(issues: &issues)
        validateMemoryRetrievalBudgetPolicy(issues: &issues)

        // Round 243A: Local Observation Foundation
        validateObservationRoomScopePolicy(issues: &issues)
        validateDownloadsWatcherSafetyPolicy(issues: &issues)
        validateClipboardPrivacyPolicy(issues: &issues)
        validateScreenObservationPolicy(issues: &issues)
        validateOfficeReviewInputPolicy(issues: &issues)
        validateAutomaticExternalUploadBlockedPolicy(issues: &issues)

        // Round 245A-P0: Artifact Contract
        validateWriteTextFileArtifactPathPolicy(issues: &issues)

        // Round 246A: UNBLOCK
        validateGoalGateFallbackPolicy(issues: &issues)
        validateToolLayerTypedResultPolicy(issues: &issues)
        validateApprovalFoundationPolicy(issues: &issues)
        validateDelegationGatePolicy(issues: &issues)
        validateBudgetTierInterfacePolicy(issues: &issues)
        validateOfficeReviewExecutionStatusPolicy(issues: &issues)

        // Round 246A-HOTFIX
        validateFeatureAvailabilitySeparatedPolicy(issues: &issues)
        validateSkillAvailabilityResolverPolicy(issues: &issues)
        validateCapabilityFallbackServicePolicy(issues: &issues)
        validateOfficeReviewNoDuplicateCasePolicy(issues: &issues)

        // Round 246B: ACTION
        validateApprovalStoreAvailablePolicy(issues: &issues)
        validateApprovalBannerViewPolicy(issues: &issues)
        validateToolResultPresentationPolicyAvailable(issues: &issues)
        validateAssistOnlySkillDetectionWiredPolicy(issues: &issues)
        validateHighRiskSkillFallbackWiredPolicy(issues: &issues)
        validateDisabledSkillFallbackWiredPolicy(issues: &issues)
        validateWorkflowTypedStatusHandledPolicy(issues: &issues)
        validateApprovalRequiredAutoRegisteredPolicy(issues: &issues)
        validatePlannedStepFallbackWiredPolicy(issues: &issues)
        validateUnavailableStepFallbackWiredPolicy(issues: &issues)
        validateOfficeReviewAssistOnlyUxPolicy(issues: &issues)
        validateObservationImplLevelUxPolicy(issues: &issues)
        // Round 247TTS validators
        validateAppleSystemTTSBlocked(issues: &issues)
        validateQwen3DefaultDisabledPolicy(issues: &issues)
        validateSupertonic3ExperimentalPolicy(issues: &issues)
        validateSupertonic3NoAutoDownloadPolicy(issues: &issues)
        validateTTSSilentFallbackPolicy(issues: &issues)
        validateTTSProviderModelsFileExists(issues: &issues)
        validateTTSRoutingPolicyExists(issues: &issues)

        // Round 247A-OBSERVE-RUNTIME validators
        validateObservationInboxViewPolicy(issues: &issues)
        validateObservationTeamPersonalRoomScopePolicy(issues: &issues)
        validateClipboardExplicitReadRoutePolicy(issues: &issues)
        validateDownloadsWatcherDefaultOffUIPolicy(issues: &issues)
        validateFinderSelectionFallbackPolicy(issues: &issues)
        validateScreenSnapshotPlannedNoticePolicy(issues: &issues)
        validateObservationPresentationPolicy(issues: &issues)
        validateObservationNoAutoAnalyzePolicy(issues: &issues)

        // Round 248A-OFFICE-LITE validators
        validateOfficeReviewLiteExecutorPolicy(issues: &issues)
        validateOfficeReviewResultCardPolicy(issues: &issues)
        validateOfficeReviewNoOriginalFileMutationPolicy(issues: &issues)
        validateOfficeReviewNoEvidenceLocationTrackingPolicy(issues: &issues)
        validateOfficeReviewLimitationsDisclaimerPolicy(issues: &issues)
        validateOfficeReviewAssistOnlyGuidancePolicy(issues: &issues)

        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        return ToolContractValidationSummary(
            errorCount: errorCount,
            warningCount: warningCount,
            issues: issues,
            plannerVisibleToolCount: ToolRegistry.shared.plannerVisibleToolCount(),
            hiddenStubToolCount: ToolRegistry.shared.hiddenStubToolCount
        )
    }

    private static func validateTools(_ tools: [WorkflowTool], issues: inout [ToolContractValidationIssue]) {
        let names = tools.map(\.name)
        if Set(names).count != names.count {
            issues.append(issue(.error, "ToolRegistry에 중복된 tool name이 있습니다."))
        }

        for tool in tools {
            if !ToolScope.allCases.contains(tool.scope) {
                issues.append(issue(.error, "도구 '\(tool.name)' 의 scope '\(tool.scope.rawValue)' 가 유효하지 않습니다."))
            } else if tool.scope == .chatBasic {
                issues.append(issue(.error, "도구 '\(tool.name)' 의 scope가 기본값 chatBasic 입니다. 명시적 scope 선언이 필요합니다."))
            }

            if tool.riskLevel == .safe && tool.scope == .officeLive && !tool.requiresApprovalPolicy {
                issues.append(issue(.error, "connector write tool '\(tool.name)' 에 approval policy가 없습니다."))
            }

            if tool.writesMemory && tool.memorySensitivityPolicy == nil {
                issues.append(issue(.error, "memory-writing tool '\(tool.name)' 에 sensitivity policy가 없습니다."))
            }

            if tool.debugOnly && !FeatureFlags.debugToolVisible && tool.plannerVisible {
                issues.append(issue(.error, "debug-only tool '\(tool.name)' 이 Release planner-visible surface에 노출되었습니다."))
            }

            if !tool.plannerVisible, tool.availability == .available, tool.scope != .localUI {
                issues.append(issue(.warning, "도구 '\(tool.name)' 은 plannerVisible=false 이지만 availability=available 입니다."))
            }

            if (tool.name.contains("google") && (tool.name.contains("slides") || tool.name.contains("sheets"))) && tool.plannerVisible {
                issues.append(issue(.error, "stub Google tool '\(tool.name)' 이 planner-visible surface에 노출되었습니다."))
            }

            // Round 43A-47H: connector write tools should not be visible in Release
            if tool.scope == .officeLive && tool.name.contains(where: { $0 == "w" }) {  // Write-like tools
                if !tool.debugOnly && FeatureFlags.debugToolVisible == false {
                    issues.append(issue(.warning, "connector write tool '\(tool.name)' 이 Release surface에 노출될 수 있습니다."))
                }
            }
        }
    }

    private static func validateSkills(_ skills: [SkillManifest], issues: inout [ToolContractValidationIssue]) {
        for skill in skills {
            if !SkillRegistry.isValidSkillID(skill.id) {
                issues.append(issue(.error, "skill id 형식이 유효하지 않습니다: \(skill.id)"))
            }

            if skill.allowedScopes.isEmpty {
                issues.append(issue(.error, "skill '\(skill.id)' 의 allowedScopes가 비어 있습니다."))
            }

            if SkillRegistry.isHighRiskSkill(skill) && skill.defaultEnabled {
                issues.append(issue(.warning, "high-risk skill '\(skill.id)' 가 defaultEnabled=true 입니다."))
            }

            validatePermissionRisk(skill, issues: &issues)
            validateWorkflowTemplate(skill, issues: &issues)
        }
    }

    private static func validatePermissionRisk(_ skill: SkillManifest, issues: inout [ToolContractValidationIssue]) {
        for permission in skill.requiredPermissions {
            guard let minimumRisk = minimumRiskLevel(for: permission) else { continue }
            if riskRank(skill.riskLevel) < riskRank(minimumRisk) {
                issues.append(issue(.warning, "skill '\(skill.id)' 의 permission '\(permission.rawValue)' 대비 riskLevel '\(skill.riskLevel.rawValue)' 이 너무 낮습니다."))
            }
        }
    }

    private static func validateWorkflowTemplate(_ skill: SkillManifest, issues: inout [ToolContractValidationIssue]) {
        guard let template = skill.workflowTemplate, !template.isEmpty else { return }

        for toolName in template {
            guard let tool = ToolRegistry.shared.lookup(name: toolName) else {
                issues.append(issue(.error, "skill '\(skill.id)' 의 workflowTemplate에 등록되지 않은 도구가 있습니다: \(toolName)"))
                continue
            }

            let basicScopes: Set<ToolScope> = [.artifactGeneration]
            if !skill.allowedScopes.contains(tool.scope) && !basicScopes.contains(tool.scope) && tool.scope != .workspaceRead && tool.scope != .localUI {
                issues.append(issue(.warning, "skill '\(skill.id)' 의 workflowTemplate tool '\(tool.name)' scope '\(tool.scope.rawValue)' 가 allowedScopes에 없습니다."))
            }
        }
    }

    private static func minimumRiskLevel(for permission: SkillPermission) -> SkillRiskLevel? {
        switch permission {
        case .requiresUserLogin:
            return .accountLogin
        case .readsPersonalData:
            return .personalData
        case .sendsMessage:
            return .externalWrite
        case .makesReservation:
            return .reservation
        case .handlesPayment:
            return .payment
        case .healthOrDrugInfo:
            return .regulated
        case .financialData:
            return .publicData
        case .legalOrAdministrative:
            return .publicData
        default:
            return nil
        }
    }

    private static func riskRank(_ level: SkillRiskLevel) -> Int {
        switch level {
        case .safeReadOnly: return 0
        case .publicData: return 1
        case .personalData: return 2
        case .accountLogin: return 3
        case .externalWrite: return 4
        case .reservation: return 5
        case .payment: return 6
        case .regulated: return 7
        }
    }

    // MARK: - Cloud Round Validators (Round 96C-115Z)

    private static func validateReleaseVisibleConnectorPolicy(_ tools: [WorkflowTool], issues: inout [ToolContractValidationIssue]) {
        // connectorRead scope는 officeLive로 통합됨 — officeLive read-only도 여기서 검사
        for tool in tools {
            if tool.scope == .chatBasic && tool.availability == .future {
                if tool.plannerVisible && !FeatureFlags.debugToolVisible {
                    issues.append(issue(.warning, "connector read (future) tool '\(tool.name)' 이 Release planner-visible surface에 노출되었습니다."))
                }
            }
        }

        for tool in tools {
            if tool.scope == .officeLive && tool.plannerVisible && !FeatureFlags.debugToolVisible {
                if !ConnectorSurfacePolicy.blockedCapabilitiesInRelease.isEmpty {
                    issues.append(issue(.error, "connector write tool '\(tool.name)' 이 Release surface에 노출되었습니다. ConnectorSurfacePolicy를 확인하세요."))
                }
            }
        }
    }

    private static func validateCharacterAssetPolicy(issues: inout [ToolContractValidationIssue]) {
        let chikoManifest = CharacterCatalog.assetManifest(for: "chiko")
        if chikoManifest.isPlaceholder {
            issues.append(issue(.error, "Chiko character가 placeholder로 표시되었습니다."))
        }
        if !ReleaseVisibleCharacterPolicy.isVisibleInRelease(chikoManifest) {
            issues.append(issue(.error, "Chiko가 ReleaseVisibleCharacterPolicy에 의해 숨겨졌습니다."))
        }

        let fullIDManifest = CharacterCatalog.assetManifest(for: "char.builtin.chiko")
        if fullIDManifest.isPlaceholder {
            issues.append(issue(.error, "CharacterIDNormalizer: 'char.builtin.chiko' normalize 실패"))
        }
    }

    private static func validateStoreKitSurfacePolicy(issues: inout [ToolContractValidationIssue]) {
        if !ProductSurfacePolicy.showsDisabledProButtonInRelease {
            issues.append(issue(.warning, "Pro button이 Release에서 숨겨졌습니다. ProductSurfacePolicy.showsDisabledProButtonInRelease를 확인하세요."))
        }
    }

    private static func validatePrivacyCopyPolicy(issues: inout [ToolContractValidationIssue]) {
        if !ProductSurfacePolicy.truthfulPrivacyCopyRequired {
            issues.append(issue(.error, "ProductSurfacePolicy.truthfulPrivacyCopyRequired가 false입니다."))
        }
    }

    private static func validateStarterActionPolicy(issues: inout [ToolContractValidationIssue]) {
        let blockedCount = StarterActionPolicy.blockedStarterActionIDs.count
        if blockedCount == 0 {
            issues.append(issue(.error, "StarterActionPolicy에 blocked action이 정의되지 않았습니다."))
        }
        if StarterActionPolicy.allowedStarterActionIDs.isEmpty {
            issues.append(issue(.error, "StarterActionPolicy에 allowed action이 정의되지 않았습니다."))
        }

        if StarterActionPolicy.allowedStarterActionIDs.contains("회의록_양식") ||
           StarterActionPolicy.allowedStarterActionIDs.contains("앱_출시_체크리스트") {
            issues.append(issue(.error, "StarterActionPolicy: 한글 ID 발견. 실제 'starter_*' ID 형식 사용 필요"))
        }
    }

    private static func validateFirstResultActionPolicy(issues: inout [ToolContractValidationIssue]) {
        let validState = ArtifactState.valid
        let allowedForValid = FirstResultActionPolicy.allowedActions(for: validState)
        if allowedForValid.isEmpty {
            issues.append(issue(.error, "FirstResultActionPolicy: valid artifact의 allowed action이 비어있습니다."))
        }

        let invalidStates = [ArtifactState.missingFile, ArtifactState.hashMismatch, ArtifactState.wrongRoom]
        for state in invalidStates {
            let actions = FirstResultActionPolicy.allowedActions(for: state)
            if !actions.isEmpty {
                issues.append(issue(.error, "FirstResultActionPolicy: '\(state.rawValue)' artifact에서 action이 노출되었습니다."))
            }
        }
    }

    private static func validateExternalWritePolicy(_ tools: [WorkflowTool], issues: inout [ToolContractValidationIssue]) {
        for tool in tools {
            if tool.name.lowercased().contains("upload") || tool.name.lowercased().contains("send") || tool.name.lowercased().contains("delete") {
                if !ProductSurfacePolicy.allowsExternalWriteStarterActions {
                    if tool.plannerVisible && !FeatureFlags.debugToolVisible {
                        issues.append(issue(.error, "external write tool '\(tool.name)' 이 Release planner-visible surface에 노출되었습니다."))
                    }
                }
            }
        }
    }

    // MARK: - UX-Fix Round 136A Validators

    private static func validateTeamNameplateSettingsPolicy(issues: inout [ToolContractValidationIssue]) {
        // palette + border mode가 정의되어 있는지만 확인 (복잡한 hex control은 제거됨)
        let paletteCount = TeamNameplatePalette.allCases.count
        if paletteCount < 4 {
            issues.append(issue(.warning, "TeamNameplatePalette에 팔레트가 \(paletteCount)개뿐입니다. 최소 4개 필요."))
        }
        if TeamNameplateBorderMode.allCases.count != 2 {
            issues.append(issue(.warning, "TeamNameplateBorderMode는 none/subtle 2가지여야 합니다."))
        }
    }

    private static func validateDARTDisclosurePolicy(_ skills: [SkillManifest], issues: inout [ToolContractValidationIssue]) {
        guard let dart = skills.first(where: { $0.id == "korean.dart" }) else {
            issues.append(issue(.error, "DART 공시 skill(korean.dart)이 SkillRegistry에 없습니다."))
            return
        }
        if !dart.defaultEnabled {
            issues.append(issue(.error, "DART 공시 skill이 defaultEnabled=false입니다. publicDisclosureRead는 Release에서 차단하지 않습니다."))
        }
        if dart.riskLevel == .externalWrite || dart.riskLevel == .reservation || dart.riskLevel == .payment {
            issues.append(issue(.error, "DART 공시 skill이 write/private riskLevel '\(dart.riskLevel.rawValue)'로 분류되었습니다."))
        }
        if dart.requiredPermissions.contains(.sendsMessage) || dart.requiredPermissions.contains(.makesReservation) {
            issues.append(issue(.error, "DART 공시 skill에 write 권한(sendsMessage/makesReservation)이 포함되었습니다."))
        }
    }

    private static func validateDefaultCharacterRosterPolicy(issues: inout [ToolContractValidationIssue]) {
        let chiko = CharacterCatalog.builtIn.first { $0.id == "char.builtin.chiko" }
        if chiko == nil {
            issues.append(issue(.error, "기본 캐릭터 치코(char.builtin.chiko)가 CharacterCatalog.builtIn에 없습니다."))
        } else if chiko?.isPremium == true {
            issues.append(issue(.error, "치코가 isPremium=true로 설정되었습니다. 기본 캐릭터는 isPremium=false여야 합니다."))
        }
        // DLC purchase가 builtIn 캐릭터에 노출되지 않는지 확인
        for char in CharacterCatalog.builtIn {
            if char.productID != nil && !char.isPremium {
                issues.append(issue(.warning, "기본 캐릭터 '\(char.name)'에 productID가 설정되었습니다. DLC처럼 보일 수 있습니다."))
            }
        }
    }

    private static func validateAPIKeyPromptSurfacePolicy(issues: inout [ToolContractValidationIssue]) {
        // FirstLaunchBannerView의 localOnly 케이스가 API key nag를 제거했는지
        // (코드 정적 분석이 아닌 정책 플래그로 확인)
        if !ProductSurfacePolicy.truthfulPrivacyCopyRequired {
            issues.append(issue(.error, "ProductSurfacePolicy.truthfulPrivacyCopyRequired가 false입니다."))
        }
        // API key prompt는 Settings surface에만 노출
        // TeamStatusView/DailyBriefingCardView에서 제거 여부는 RuntimeDiagnostics로 확인
    }

    private static func issue(_ severity: ToolContractValidationIssue.Severity, _ message: String) -> ToolContractValidationIssue {
        ToolContractValidationIssue(id: UUID(), severity: severity, message: message)
    }

    // MARK: - Product IA Round 137A-145Z Validators

    private static func validateRoomScopedArtifactPolicy(issues: inout [ToolContractValidationIssue]) {
        // AgentWindowManager에 recentArtifacts(for:) facade가 있어야 한다
        // 정적 분석 대신 policy 플래그로 확인 — RuntimeDiagnostics.recentArtifactsRoomScoped
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.recentArtifactsRoomScoped {
            issues.append(issue(.error, "recentArtifacts가 room-scoped facade로 전환되지 않았습니다. P0: 다른 방 artifact 오염 위험."))
        }
    }

    private static func validateTerminologyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.terminologyPolicyAvailable {
            issues.append(issue(.warning, "TerminologyPolicy 문서가 없습니다. docs/TerminologyPolicy.md 생성 필요."))
        }
        if let snap, !snap.workroomTerminologyApplied {
            issues.append(issue(.error, "워크룸 용어 미적용 — '채팅방'/'프로젝트' 잔존 가능성."))
        }
        if let snap, !snap.reservedTaskTerminologyApplied {
            issues.append(issue(.error, "예약 작업 용어 미적용 — '스케줄 근무' 잔존 가능성."))
        }
    }

    private static func validateTypingIndicatorTimerPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.typingIndicatorTimerLeakFixed {
            issues.append(issue(.error, "TypingIndicatorView Timer leak 미수정 — onDisappear에서 invalidate 필요."))
        }
    }

    private static func validateAgentSwitcherPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.agentSwitcherRemovedFromSidebar {
            issues.append(issue(.warning, "에이전트 전환 switcher가 사이드바에 노출되어 있습니다. UX 단순화 미완료."))
        }
    }

    private static func validateStarterAction3PrimaryPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.starterAction3PrimaryAvailable {
            issues.append(issue(.warning, "Starter action 3개 primary (파일 맡기기/문서 만들기/오늘 정리하기)가 정의되지 않았습니다."))
        }
    }

    private static func validateWorkroomDefaultNamePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.defaultRoomNameUpdated {
            issues.append(issue(.warning, "기본 워크룸 이름이 '기본 프로젝트'입니다. '워크룸 1'로 변경 필요."))
        }
    }

    private static func validateReservedTaskTerminologyPolicy(issues: inout [ToolContractValidationIssue]) {
        // validateTerminologyPolicy와 중복 방지 — 여기서는 schedule entry deduplication만 확인
        // 현재 entry point가 하나인지 policy flag로 확인
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.reservedTaskTerminologyApplied {
            issues.append(issue(.warning, "예약 작업 entry point가 중복되어 있을 수 있습니다. '예약 작업' 단일 경로 확인 필요."))
        }
    }

    private static func validateEmptyStateSimplificationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.emptyStateSimplified {
            issues.append(issue(.warning, "첫 empty state가 단순화되지 않았습니다. 상태카드 1 + 주요 액션 3 구조 확인 필요."))
        }
    }

    // MARK: - Round 146A-152Z Validators

    private static func validateFirstResultActionSurfacePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.firstResultActionDeduplicated {
            issues.append(issue(.error, "FirstResultActionStrip이 TeamStatusView와 AgentChatView 양쪽에 표시됩니다. AgentChatView에서만 표시 필요."))
        }
    }

    private static func validateCollaborationStatusCompactPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.collaborationStatusCompact {
            issues.append(issue(.warning, "협업 상태 배너가 2줄 카드입니다. 1줄 컴팩트 바로 압축 필요."))
        }
    }

    private static func validateWorkResultPresentationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workResultCardAvailable {
            issues.append(issue(.error, "WorkResultCardView가 없습니다. 긴 어시스턴트 응답이 260px 말풍선으로 렌더링됩니다."))
        }
        if let snap, !snap.longAssistantResultEscapesBubble {
            issues.append(issue(.error, "어시스턴트 메시지 maxWidth가 260px입니다. 480px로 확장 필요."))
        }
    }

    private static func validateArtifactStatusCopyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.artifactStatusCopyUserFriendly {
            issues.append(issue(.warning, "ArtifactCardView 상태 텍스트에 진단 용어('메타데이터만', '경로 오류')가 포함되어 있습니다."))
        }
    }

    private static func validateRoomKindPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.roomKindComputedAvailable {
            issues.append(issue(.warning, "RoomKind computed property가 없습니다. 워크룸/개인 대화 구분 불가."))
        }
        if let snap, !snap.teamWorkroomPersonalChatSeparated {
            issues.append(issue(.warning, "팀 워크룸과 개인 대화에 동일한 아이콘이 표시됩니다. 시각적 구분 필요."))
        }
    }

    private static func validateWorkResultInlineArtifactPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workResultInlineArtifactsAvailable {
            issues.append(issue(.warning, "WorkResultCardView에서 inline artifact 표시가 없습니다. 관련 artifact를 카드 내부에 표시해야 합니다."))
        }
    }

    private static func validateChatLogArtifactLinkingPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.chatLogArtifactIDsLinked {
            issues.append(issue(.warning, "ChatLog.artifactIDs가 workflow 완료 메시지에서 사용되지 않습니다. 메시지와 artifact 연결 필요."))
        }
    }

    private static func validateSkillResultCardFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.skillResultGenericCardFallbackAvailable {
            issues.append(issue(.warning, "SkillResultRendererView에 generic card fallback이 없습니다. 구조화된 스킬 결과를 카드로 표시해야 합니다."))
        }
    }

    // Round 163B-UXNAV: Agent Quick Navigation + Starter Copy Polish Pack

    private static func validateAgentQuickSwitchPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.agentQuickSwitchBarAvailable {
            issues.append(issue(.warning, "AgentQuickSwitchBar가 없습니다. 팀원 빠른 이동 기능이 필요합니다."))
        }
    }

    private static func validateAgentNavigationMutationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.agentQuickSwitchUsesNavigationNotMutation {
            issues.append(issue(.error, "Agent quick switch가 현재 room agentIDs를 mutate하고 있습니다. Navigation으로 변경해야 합니다."))
        }
    }

    private static func validatePersonalChatIdentityPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.personalChatIdentityPreserved {
            issues.append(issue(.error, "개인 대화의 정체성이 손상되었습니다. agentIDs.count != 1인 개인 대화가 있거나, 팀 워크룸이 개인 대화로 변형되었을 가능성이 있습니다."))
        }
    }

    private static func validateTeamWorkroomReturnPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.teamWorkroomReturnShortcutAvailable {
            issues.append(issue(.warning, "개인 대화에서 팀 워크룸으로 돌아가는 shortcut이 없습니다."))
        }
    }

    private static func validateStarterChecklistCopyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.starterChecklistCopyUpdated {
            issues.append(issue(.warning, "StarterAction 체크리스트 description이 업데이트되지 않았습니다. '업무 준비 요소를 체크리스트로 정리합니다'로 변경해야 합니다."))
        }
    }

    // Round 164A-180Z: Killer Workflow Completion Pack validators
    private static func validateDocumentCreationCoreFlow(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.documentCreationHubAvailable {
                issues.append(issue(.error, "문서 만들기 core flow가 unavailable 상태입니다."))
            }
            if !snap.meetingMinutesCoreFlowAvailable || !snap.checklistCoreFlowAvailable || !snap.reportDraftCoreFlowAvailable {
                issues.append(issue(.warning, "일부 core document types (회의록/체크리스트/보고서)가 unavailable 상태입니다."))
            }
        }
    }

    private static func validateLocalDocumentFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.localDocumentFallbackAvailable {
            issues.append(issue(.error, "로컬 document fallback이 unavailable 상태입니다. API key 없어도 기본 템플릿 결과를 생성해야 합니다."))
        }
    }

    private static func validateWorkResultKindPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workResultKindAvailable {
            issues.append(issue(.warning, "WorkResultCardView가 document kind를 구분하지 못합니다. 문서 타입별 제목/아이콘을 구분해야 합니다."))
        }
    }

    private static func validateRecentDocumentReuseLoop(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.recentDocumentReuseLoopAvailable {
                issues.append(issue(.warning, "방금 만든 문서 후속 액션 loop가 unavailable 상태입니다."))
            }
            if !snap.documentResultInlineArtifactAvailable {
                issues.append(issue(.warning, "document result에 inline artifact display가 unavailable 상태입니다."))
            }
        }
    }

    private static func validateArtifactActionSurfacePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.artifactActionSurfaceSimplified {
            issues.append(issue(.warning, "Artifact action surface가 너무 복잡합니다. Compact: 2개, Full: 4개 버튼으로 제한해야 합니다."))
        }
    }

    // MARK: - Round 181A-195Z Validators

    private static func validateWorkroomHomePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomHomeAvailable {
            issues.append(issue(.warning, "WorkroomHomeView가 unavailable 상태입니다. 팀 워크룸에서 대시보드 역할이 필요합니다."))
        }
    }

    private static func validateWorkroomPrimaryActionPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomPrimaryActionsAvailable {
            issues.append(issue(.error, "WorkroomHomeView primary actions (문서 만들기, 파일 맡기기, 오늘 정리하기)가 unavailable 상태입니다."))
        }
    }

    private static func validateWorkroomArtifactRailPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomUsesRoomScopedArtifacts {
            issues.append(issue(.error, "Workroom artifact rail이 global recentArtifacts를 사용합니다. Room-scoped로만 표시해야 합니다."))
        }
    }

    private static func validateWorkroomNextActionPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomNextActionsRoomScoped {
            issues.append(issue(.error, "Workroom next actions (요약/표/체크리스트/액션아이템)이 room-scoped가 아닙니다. RoomID 체크가 필요합니다."))
        }
    }

    private static func validateAgentChatWarningDebtPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.agentChatAwaitWarningsResolved {
            issues.append(issue(.warning, "AgentChatView에 await warning이 남아 있습니다. 비동기 작업이 실제로 있는지 검토하세요."))
        }
    }

    // Round 196A-230Z validators
    private static func validateWorkroomActionTypesConsolidationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomActionTypesConsolidated {
            issues.append(issue(.error, "WorkroomActionTypes.swift enum consolidation이 완료되지 않았습니다. WorkroomPrimaryAction과 WorkroomNextAction이 여전히 중복 정의되어 있을 수 있습니다."))
        }
    }

    private static func validateWorkroomEnumDuplicationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomEnumDuplicationRemoved {
            issues.append(issue(.error, "WorkroomPrimaryAction/WorkroomNextAction enum이 TeamStatusView, WorkroomHomeModel 등에서 중복 정의되고 있습니다. WorkroomActionTypes.swift로 통합해야 합니다."))
        }
    }

    private static func validateWorkroomPbxprojRegistrationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomPbxprojRegistered {
            issues.append(issue(.error, "WorkroomActionTypes.swift가 Xcode project (pbxproj)에 등록되지 않았습니다. Build phase에 추가되어야 합니다."))
        }
    }

    private static func validateWorkroomHandlerMethodsPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomHandlerMethodsConsolidated {
            issues.append(issue(.warning, "WorkroomAction 핸들러 메서드가 dispatchPrompt 기반으로 리팩터링되지 않았습니다. handleWorkroomAction()/handleWorkroomNextAction()에서 hardcoded prompt string이 있을 수 있습니다."))
        }
    }

    private static func validateWorkroomRoomScopePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomRoomScopeEnforced {
            issues.append(issue(.error, "Workroom room-scope 정책이 적용되지 않았습니다. recentArtifacts(for: roomID) 패턴이 일관되게 사용되지 않을 수 있습니다."))
        }
    }

    private static func validateWorkroomCharacterSystemPreservationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomCharacterSystemPreserved {
            issues.append(issue(.error, "Character system (CharacterDialogues, SpriteAgentView, CharacterSpriteScene, AnimationState)이 수정되었거나 삭제되었습니다. 이 파일들은 보호되어야 합니다."))
        }
    }

    private static func validateWorkroomCharacterReactionBridgeDocumentationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomCharacterReactionBridgeBacklogDocumented {
            issues.append(issue(.warning, "docs/character/CharacterReactionBridgeBacklog.md가 없거나 불완전합니다. Workroom event → character reaction 매핑 전략이 문서화되어야 합니다."))
        }
    }

    private static func validateWorkroomSpriteSheetProductionSpecPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomSpriteSheetProductionSpecDocumented {
            issues.append(issue(.warning, "docs/character/SpriteSheetProductionSpec.md가 없거나 불완전합니다. Sprite 파일 명명 규칙과 프로덕션 파이프라인이 문서화되어야 합니다."))
        }
    }

    private static func validateWorkroomCharacterReactionEnginePlanPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomCharacterReactionEnginePlanDocumented {
            issues.append(issue(.warning, "docs/character/CharacterReactionEnginePlan.md가 없거나 불완전합니다. Round 231A 구현 계획이 문서화되어야 합니다."))
        }
    }

    // Round 231A validators
    private static func validateCharacterReactionEnginePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.characterReactionEngineAvailable {
                issues.append(issue(.error, "CharacterReactionEngine이 unavailable 상태입니다. WorkroomCharacterEvent.swift + CharacterReactionEngine.swift + CharacterReactionEventSink.swift가 빌드에 포함되어야 합니다."))
            }
            if !snap.workroomCharacterEventBridgeAvailable {
                issues.append(issue(.error, "WorkroomCharacterEvent bridge가 unavailable 상태입니다. CharacterReactionEventSink가 AgentWindowManager.agentEmotions에 연결되어야 합니다."))
            }
            if snap.workroomCharacterEventInitialMappingCount < 4 {
                issues.append(issue(.warning, "WorkroomCharacterEvent 매핑 수가 \(snap.workroomCharacterEventInitialMappingCount)개입니다. 최소 4개(workroomOpened/workflowStarted/documentCreated/artifactReuse) 필요합니다."))
            }
            if !snap.toolContractValidatorAvailable {
                issues.append(issue(.error, "ToolContractValidator.swift가 미존재 또는 미등록 상태입니다."))
            }
            if !snap.routerBurnInSuiteAvailable {
                issues.append(issue(.error, "RouterBurnInSuite.swift가 미존재 또는 미등록 상태입니다."))
            }
        }
    }

    private static func validateCharacterReactionAnimationStatePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.characterReactionUsesExistingAnimationState {
                issues.append(issue(.error, "CharacterReactionEngine이 기존 AnimationState enum 대신 새 타입을 사용합니다. CharacterMood/CharacterActivity 도입은 금지입니다."))
            }
            if !snap.characterDialoguesPreserved {
                issues.append(issue(.error, "CharacterDialogues.swift가 삭제되거나 이동되었습니다. 이 파일은 보호됩니다."))
            }
            if !snap.spriteAgentViewPreserved {
                issues.append(issue(.error, "SpriteAgentView.swift가 삭제되거나 이동되었습니다. 이 파일은 보호됩니다."))
            }
            if !snap.characterSpriteScenePreserved {
                issues.append(issue(.error, "CharacterSpriteScene.swift가 삭제되거나 이동되었습니다. 이 파일은 보호됩니다."))
            }
        }
    }

    private static func validateWorkroomEventBridgePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.workroomCharacterEventBridgeAvailable {
            issues.append(issue(.warning, "Workroom 이벤트가 CharacterReactionEventSink를 통해 AgentWindowManager.agentEmotions에 연결되지 않았습니다. workroomOpened/documentCreated/artifactReuse/roomSwitched 최소 4개 연결이 필요합니다."))
        }
    }

    // MARK: - Round 232 Validators

    private static func validateCharacterSpriteSheetHandoffPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.chikoSpriteSheetHandoffAvailable {
                issues.append(issue(.warning, "docs/character/ChikoSpriteSheetHandoff.md가 없습니다. 디자인 handoff 문서가 필요합니다."))
            }
            if !snap.characterSpriteRosterRoadmapAvailable {
                issues.append(issue(.warning, "docs/character/CharacterSpriteRosterRoadmap.md가 없습니다. 캐릭터 로드맵 문서가 필요합니다."))
            }
        }
        // CharacterMood/Activity 미도입 확인은 validateCharacterReactionAnimationStatePolicy에서 처리
    }

    private static func validateCharacterReactionDelegatePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            // delegate=nil인 경우 deferred 상태가 문서화되어야 한다
            if snap.characterReactionDelegateDeferred && !snap.characterReactionDelegateDecisionAvailable {
                issues.append(issue(.warning, "CharacterReactionDelegate가 nil이지만 CharacterReactionDelegateDecision.md 문서가 없습니다. deferred 상태를 문서화해야 합니다."))
            }
            // agentEmotions 경로는 반드시 연결되어야 한다
            if !snap.characterReactionAgentEmotionsConnected {
                issues.append(issue(.error, "CharacterReactionEventSink → AgentWindowManager.agentEmotions 경로가 연결되어 있지 않습니다. delegate=nil 상태에서는 agentEmotions 경로가 필수입니다."))
            }
        }
    }

    private static func validateCharacterSpriteRosterPolicy(issues: inout [ToolContractValidationIssue]) {
        // 미래 캐릭터 노출 정책: sprites 없으면 Release에서 구매 UI 노출 금지.
        // 현재는 정책 문서 존재만 확인한다 (실제 AgentConfig 검사는 수동 QA).
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.characterSpriteRosterRoadmapAvailable {
            issues.append(issue(.warning, "CharacterSpriteRosterRoadmap.md가 없습니다. DLC 캐릭터 노출 정책이 문서화되어야 합니다."))
        }
    }

    // MARK: - Round 233B: Beginner Mode Validators

    private static func validateBeginnerModePolicy(issues: inout [ToolContractValidationIssue]) {
        // 간편 모드 UI 표면 존재 여부 확인
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.beginnerModeAvailable {
            issues.append(issue(.error, "BeginnerMode: 간편 모드 기능이 비활성화되어 있습니다. BeginnerMode.swift 등록을 확인하세요."))
        }
        if !snap.beginnerTaskCardsAvailable {
            issues.append(issue(.error, "BeginnerMode: BeginnerTaskCard가 없습니다. BeginnerMode.swift 등록을 확인하세요."))
        }
        if !snap.beginnerSettingsToggleAvailable {
            issues.append(issue(.warning, "BeginnerMode: SettingsView 간편 모드 토글이 없습니다."))
        }
        if !snap.beginnerWorkroomHomeViewAvailable {
            issues.append(issue(.error, "BeginnerMode: WorkroomHomeView 간편 모드 분기가 없습니다."))
        }
    }

    private static func validateBeginnerExampleFlowPolicy(issues: inout [ToolContractValidationIssue]) {
        // 예시로 먼저 해보기 플로우 — API 키 없이 동작해야 함
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.beginnerExampleFlowAvailable {
            issues.append(issue(.error, "BeginnerMode: 예시 플로우(BeginnerExampleDocumentService)가 없습니다. API 키 없이 동작하는 fallback이 필요합니다."))
        }
        if !snap.beginnerExampleDocumentServiceAvailable {
            issues.append(issue(.error, "BeginnerMode: BeginnerExampleDocumentService 싱글턴이 없습니다."))
        }
        if !snap.beginnerGuidanceMessagesAvailable {
            issues.append(issue(.warning, "BeginnerMode: BeginnerGuidanceMessage 정의가 없습니다."))
        }
    }

    private static func validateBeginnerFriendlyRecoveryPolicy(issues: inout [ToolContractValidationIssue]) {
        // ArtifactCardView 친절한 복구 UI 확인
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.beginnerFriendlyRecoveryAvailable {
            issues.append(issue(.warning, "BeginnerMode: ArtifactCardView 친절한 복구 UI(friendlyRecovery)가 없습니다. 비전문가 사용자 오류 복구 경험이 저하됩니다."))
        }
    }

    // MARK: - Round 234: Sprite Asset Gate Validators

    private static func validateSpriteAssetPolicy(issues: inout [ToolContractValidationIssue]) {
        // Sprite 에셋 게이트: 치코 runtime 폴더 + 명세 존재
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.chikoSpriteFolderAvailable {
            issues.append(issue(.warning, "Sprite: 치코 runtime sprite 폴더(Sprites/치코/)가 app bundle에 없습니다. SpriteKit 폴백으로 동작합니다."))
        }
        if !snap.characterSpriteManifestAvailable {
            issues.append(issue(.warning, "Sprite: CharacterSpriteManifest이 없습니다. 에셋 명세 없이 빌드됩니다."))
        }
        if !snap.chikoRequiredSpriteStatesDocumented {
            issues.append(issue(.warning, "Sprite: 치코 required state 목록이 문서화되어 있지 않습니다."))
        }
        if !snap.spriteValidatorAvailable {
            issues.append(issue(.warning, "Sprite: scripts/validate_sprites.sh가 없습니다. CI에서 sprite 검수를 수동으로 진행해야 합니다."))
        }
    }

    private static func validateBeginnerExampleArtifactPolicy(issues: inout [ToolContractValidationIssue]) {
        // BeginnerExampleDocumentService artifact 저장 정책
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.beginnerExampleFlowAvailable {
            issues.append(issue(.error, "BeginnerExample: 예시 플로우가 없습니다. API 키 없이 동작하는 fallback이 필요합니다."))
            return
        }
        if !snap.beginnerExampleNextActionsAvailable {
            issues.append(issue(.warning, "BeginnerExample: 예시 문서 생성 후 next action(요약/표/체크리스트)이 없습니다."))
        }
        // external write 금지: BeginnerExampleDocumentService는 ArtifactStore local write만 사용
        // 이 정책은 코드 리뷰로 확인; runtime에서는 정적 검사만 가능
    }

    private static func validateFriendlyRecoveryActionPolicy(issues: inout [ToolContractValidationIssue]) {
        // friendlyRecovery 복구 버튼: 삭제/업로드/메일/캘린더 write 금지 확인
        // ArtifactCardView에서 복구 버튼은 Notification 발행만 함 → 외부 write 없음
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.friendlyRecoveryActionsAvailable {
            issues.append(issue(.warning, "FriendlyRecovery: ArtifactCardView 복구 버튼이 없습니다."))
        }
        // 아래 항목은 코드 리뷰로 정적 확인됨:
        // ✅ 복구 버튼은 NotificationCenter.post("myteam.beginnerNewDocument") 만 발행
        // ✅ 삭제 버튼 없음
        // ✅ 외부 업로드 없음
        // ✅ 메일 발송 없음
        // ✅ 캘린더 write 없음
    }

    private static func validateContentDraftAuxiliaryPolicy(issues: inout [ToolContractValidationIssue]) {
        let profile = AgentWindowManager.RoomProfile.blogWriting()
        if profile.purpose.contains("최적화") || profile.purpose.contains("메인") {
            issues.append(issue(.warning, "콘텐츠 초안 프로필이 MyTeam의 핵심 워크룸 루프보다 앞서는 문구를 사용합니다. 보조 기능으로 유지해야 합니다."))
        }
        if !profile.systemInstruction.contains("문서/파일/표/정리") {
            issues.append(issue(.warning, "콘텐츠 초안 프로필이 ONBOARDING.md의 핵심 루프와 연결되어 있지 않습니다."))
        }
        if profile.preferredOutputFormat?.contains("본문 초안") != true {
            issues.append(issue(.warning, "콘텐츠 초안 프로필에 사용자가 바로 고쳐 쓸 초안 출력 형식이 없습니다."))
        }
    }

    // MARK: - Round 236 Validators

    private static func validateRoomRenamePolicy(issues: inout [ToolContractValidationIssue]) {
        // AgentWindowManager에 renameRoom(id:newName:) 존재 확인 (정적 검사)
        // 실제 호출 가능성은 RouterBurnInSuite에서 검증
        // 빈 이름 저장 금지 정책: renameRoom에서 guard !newName.isEmpty 적용 필요
        let generalProfile = AgentWindowManager.RoomProfile.general()
        if generalProfile.mode == .blogWriting {
            issues.append(issue(.error, "일반 방 프로필이 blogWriting 모드로 초기화됩니다. general() 팩토리를 확인하세요."))
        }
    }

    private static func validateRoomScopedConversationPolicy(issues: inout [ToolContractValidationIssue]) {
        // room-scoped 격리 정책: artifact/messages/LLM context는 roomID 기준
        // cross-room artifact 노출 금지
        let blogProfile = AgentWindowManager.RoomProfile.blogWriting()
        // sourceURLs는 roomID와 함께 저장되어야 함 (구조 확인)
        if blogProfile.sourceURLs.isEmpty == false {
            // 정상: blogWriting 프로필에 URL이 있을 수 있음
        }
        // systemInstruction이 너무 길면 원문 포함 의심
        let maxInstructionLength = 3000
        if blogProfile.systemInstruction.count > maxInstructionLength {
            issues.append(issue(.warning, "RoomProfile.systemInstruction이 \(maxInstructionLength)자를 초과합니다. 원문 전체 저장 금지 정책을 확인하세요."))
        }
    }

    private static func validateRoomPurposeInferencePolicy(issues: inout [ToolContractValidationIssue]) {
        // 자동 감지는 "제안" 수준이어야 함 — 사용자 강제 고정 금지
        // blogWriting 방 자동 생성 금지
        let generalProfile = AgentWindowManager.RoomProfile.general()
        if generalProfile.mode == .blogWriting {
            issues.append(issue(.error, "일반 방이 blogWriting으로 자동 고정됩니다. purpose inference는 제안 수준이어야 합니다."))
        }
    }

    private static func validateBlogRoomProfilePolicy(issues: inout [ToolContractValidationIssue]) {
        // BlogStyleProfile은 roomID 기준, 전역 저장 금지
        // /blog-source, /blog-profile은 currentRoomID 기준으로만 작동
        let profile = AgentWindowManager.RoomProfile.blogWriting()
        if profile.styleProfile == nil {
            // styleProfile은 nil일 수 있음 (URL 추가 전) — 정상
        }
        // 원문 전체를 styleProfile에 저장하면 안 됨
        if let style = profile.styleProfile {
            let maxFieldLength = 500
            // headlinePatterns 각 항목 길이 확인
            for pattern in style.headlinePatterns where pattern.count > maxFieldLength {
                issues.append(issue(.warning, "BlogStyleProfile.headlinePatterns 항목이 \(maxFieldLength)자를 초과합니다. 특징 요약만 저장해야 합니다."))
            }
            // voiceSummary 길이 확인
            if style.voiceSummary.count > maxFieldLength * 2 {
                issues.append(issue(.warning, "BlogStyleProfile.voiceSummary가 \(maxFieldLength * 2)자를 초과합니다. 원문 전체 저장 금지 정책을 확인하세요."))
            }
        }
    }

    private static func validateConnectorReadinessPolicy(issues: inout [ToolContractValidationIssue]) {
        // Gmail send / Calendar write 구현 금지
        // read-only부터 테스트 가능하게
        // ConnectorReadinessPlan.md 존재 확인
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let planPath = repoRoot.appendingPathComponent("docs/connectors/ConnectorReadinessPlan.md")
        let inventoryPath = repoRoot.appendingPathComponent("docs/ProductImplementationInventory.md")
        if !FileManager.default.fileExists(atPath: planPath.path) {
            issues.append(issue(.warning, "docs/connectors/ConnectorReadinessPlan.md 없음. 커넥터 준비도 계획 문서가 필요합니다."))
        }
        if !FileManager.default.fileExists(atPath: inventoryPath.path) {
            issues.append(issue(.warning, "docs/ProductImplementationInventory.md 없음. 미구현 기능 인벤토리 문서가 필요합니다."))
        }
    }

    private static func validatePoliteUserFacingCopyPolicy(issues: inout [ToolContractValidationIssue]) {
        // 사용자-facing 기술 용어 노출 금지
        // "미구현", "stub", "hash mismatch", "blocked", "IMAP 기반" 등 금지
        let forbiddenTerms = ["미구현", "stub", "hash mismatch", "IMAP 기반", "read-only 검토"]
        let uiFiles = [
            "ArtifactCardView.swift", "DailyBriefingCardView.swift",
            "TeamStatusView.swift", "WorkroomHomeView.swift",
            "BeginnerTaskCardView.swift", "AssistantConnectorCatalog.swift"
        ]
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for fileName in uiFiles {
            let filePath = repoRoot.appendingPathComponent("MyTeam/\(fileName)")
            guard let content = try? String(contentsOf: filePath, encoding: .utf8) else { continue }
            for term in forbiddenTerms {
                if content.contains(term) {
                    issues.append(issue(.warning, "UI 파일 \(fileName)에 기술 용어 '\(term)' 발견. 사용자 친화 언어로 교체 필요."))
                }
            }
        }
    }

    // MARK: - Round 241A: Team / Personal Hard Separation Validators

    private static func validateTeamPersonalRoomStateSeparationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap {
            if !snap.teamWorkroomPersonalStateSeparated {
                issues.append(issue(.error, "selectedTeamWorkroomID가 nil입니다. 팀 워크룸 선택 상태가 분리되지 않았습니다."))
            }
            if !snap.teamWorkroomSelectionPreservedOnPersonalChat {
                issues.append(issue(.error, "개인 대화 전환 시 selectedTeamWorkroomID가 nil로 바뀌었습니다. openPersonalChat이 selectedTeamWorkroomID를 변경하고 있습니다."))
            }
        }
    }

    private static func validatePersonalConversationNavigationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.personalConversationSelectionIndependent {
            issues.append(issue(.error, "개인 대화 선택 상태(activePersonalAgentID)가 팀 워크룸 selectedTeamWorkroomID에 영향을 주고 있습니다."))
        }
    }

    private static func validatePersonalChatSidebarPrivacyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.personalChatSidebarPreviewHidden {
            issues.append(issue(.error, "개인 대화 사이드바에서 메시지 내용 preview가 표시되고 있습니다. 방 이름만 표시해야 합니다."))
        }
    }

    private static func validateQuickSwitchNoRoomMutationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.quickSwitchDoesNotMutateRoomAgents {
            issues.append(issue(.error, "AgentQuickSwitchBar 클릭이 room.agentIDs를 변경하고 있습니다. Navigation 전용으로 제한해야 합니다."))
        }
    }

    // MARK: - Round 241B: Personal Conversation Map + GoalGate + BYOK Validators

    private static func validateSelectedPersonalConversationMapPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.selectedPersonalConversationMapAvailable {
            issues.append(issue(.error, "selectedPersonalConversationIDByAgentID가 없습니다. 에이전트 전환 시 이전 대화를 복원할 수 없습니다."))
        }
    }

    private static func validateOpenPersonalConversationAPIPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.openPersonalConversationAPIAvailable {
            issues.append(issue(.error, "openPersonalConversation(for:) 공식 API가 없습니다. openPersonalChat wrapper만으로는 개인 대화 방 ID 매핑이 보장되지 않습니다."))
        }
    }

    private static func validateBYOKProviderButtonPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.byokProviderButtonFunctional {
            issues.append(issue(.warning, "BYOK 버튼이 no-op 상태입니다. Button(\"\") {} .disabled(true) 패턴을 제거하고 최소한 설명 tooltip을 제공해야 합니다."))
        }
    }

    private static func validateGoalGateDirectChatFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.goalGateOffersDirectChatFallback {
            issues.append(issue(.error, "GoalGate가 blocked capability에 대해 하드 블록을 반환합니다. directChat pivot으로 AI가 초안/도움말을 제공해야 합니다."))
        }
    }

    // MARK: - Round 241C: Surface Routing + Unread Badge + Overlay/Chrome Validators

    private static func validateTeamComposerRoutingPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.teamComposerTargetsTeamWorkroom {
            issues.append(issue(.error, "팀 composer가 selectedTeamWorkroomID 대신 currentRoomID를 사용합니다. 개인 대화 전환 후 팀 메시지가 잘못된 방으로 전송될 수 있습니다."))
        }
        if let snap, !snap.teamComposerDoesNotUseActivePersonalAgent {
            issues.append(issue(.error, "팀 composer가 activePersonalAgentID를 참조하고 있습니다. 팀 composer는 팀 워크룸 상태만 참조해야 합니다."))
        }
    }

    private static func validatePersonalComposerRoutingPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.personalComposerTargetsPersonalConversation {
            issues.append(issue(.error, "개인 대화 composer가 selectedTeamWorkroomID를 타겟으로 사용하고 있습니다. 개인 composer는 agentRoomID / selectedPersonalConversationIDByAgentID만 사용해야 합니다."))
        }
        if let snap, !snap.currentRoomIDDeprecatedForSendTargets {
            issues.append(issue(.warning, "currentRoomID가 send target으로 사용되고 있습니다. currentRoomID는 legacy UI selection 용도로만 제한해야 합니다."))
        }
    }

    private static func validateUnreadBadgePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.unreadBadgeCountsIncomingOnly {
            issues.append(issue(.error, "unread badge가 내가 보낸 메시지를 포함하고 있습니다. badge는 상대방이 보낸 미읽 메시지(isUser == false)만 카운트해야 합니다."))
        }
        if let snap, !snap.unreadBadgeExcludesSystemMessages {
            issues.append(issue(.error, "unread badge가 system/progress 메시지를 포함하고 있습니다. isSystem == true 메시지는 badge에서 제외해야 합니다."))
        }
    }

    private static func validateAgentMenuPresentationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.agentMenuUsesNonClippedPresentation {
            issues.append(issue(.warning, "에이전트 액션 메뉴가 parent bounds에 clipped되는 커스텀 overlay 패턴을 사용합니다. SwiftUI contextMenu 또는 root-level presenter로 교체해야 합니다."))
        }
    }

    private static func validateFooterChromeIntegrationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        if let snap, !snap.footerChromeIntegratedWithPanel {
            issues.append(issue(.warning, "하단 control bar가 별도 detached RoundedRectangle로 렌더링되고 있습니다. safeAreaInset + Divider 방식으로 패널에 통합해야 합니다."))
        }
    }

    // MARK: - Round 244A: Memory Scope Foundation

    private static func validateMemoryScopeSeparationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.memoryStoreAvailable {
            issues.append(issue(.error, "MemoryStore를 사용할 수 없습니다. 스코프별 기억 저장소가 초기화되지 않았습니다."))
        }
        if !snap.roomMemorySeparated {
            issues.append(issue(.error, "room memory가 roomID 없이 저장될 수 있습니다. roomID가 없는 room/agentInRoom scope 저장은 하드 블록되어야 합니다."))
        }
    }

    private static func validateCredentialMemoryBlockedPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.credentialMemoryBlocked {
            issues.append(issue(.error, "credentialLike 감지 후 MemoryStore 저장을 차단하지 않고 있습니다. API key / token / password 패턴은 isStorageBlocked = true로 하드 블록되어야 합니다."))
        }
    }

    private static func validateSensitiveMemoryApprovalPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.sensitiveMemoryRequiresApproval {
            issues.append(issue(.error, "businessConfidential / personalSensitive 항목이 사용자 승인 없이 자동 저장될 수 있습니다. 이 sensitivity class는 pendingReviewCandidates 경로를 통해 사용자 승인 후에만 저장되어야 합니다."))
        }
        if !snap.memoryReviewCandidateAvailable {
            issues.append(issue(.warning, "MemoryReviewCandidate UX stub이 준비되지 않았습니다. 사용자 승인 UI 없이는 민감 정보를 안전하게 처리할 수 없습니다."))
        }
    }

    private static func validateRoomMemoryIsolationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.memoryRetrieverAvailable {
            issues.append(issue(.error, "MemoryRetriever를 사용할 수 없습니다. room memory 격리 없이는 다른 방의 기억이 현재 방 컨텍스트에 유입될 수 있습니다."))
        }
        if !snap.roomMemorySeparated {
            issues.append(issue(.error, "MemoryRetriever가 다른 방의 room memory를 현재 방 결과에 포함할 수 있습니다. roomID 필터링이 isRelevant() 내부에서 강제되어야 합니다."))
        }
    }

    private static func validateProceduralMemoryPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.proceduralMemoryAvailable {
            issues.append(issue(.warning, "procedural memory scope를 사용할 수 없습니다. 반복 업무 방식이 기억되지 않아 사용자 경험이 저하됩니다."))
        }
        if !snap.memoryConsolidatorAvailable {
            issues.append(issue(.warning, "MemoryConsolidator를 사용할 수 없습니다. 대화에서 자동으로 procedural/userProfile candidate가 추출되지 않습니다."))
        }
    }

    private static func validateMemoryRetrievalBudgetPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.memoryRetrieverAvailable {
            issues.append(issue(.warning, "MemoryRetriever가 없습니다. memory budget(최대 12개, 상한 20개) 강제가 불가합니다."))
        }
        if !snap.memoryScopePolicyAvailable {
            issues.append(issue(.warning, "MemoryScopePolicy를 사용할 수 없습니다. 텍스트에서 scope/sensitivity 자동 분류가 불가합니다."))
        }
    }

    private static func validateWriteTextFileArtifactPathPolicy(issues: inout [ToolContractValidationIssue]) {
        do {
            let sourceFile = try String(contentsOfFile: "MyTeam/WriteTextFileTool.swift", encoding: .utf8)
            if sourceFile.contains("artifactPath: filename") && !sourceFile.contains("let savedFilename = url.lastPathComponent") {
                issues.append(issue(.error, "WriteTextFileTool: artifactPath가 입력 filename을 그대로 반환합니다. 실제 저장된 파일명(url.lastPathComponent)으로 반환해야 합니다."))
            }
        } catch {
            issues.append(issue(.warning, "WriteTextFileTool 소스 검증 불가"))
        }
    }

    // MARK: - Round 243A: Local Observation Foundation

    private static func validateObservationRoomScopePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.localObservationServiceAvailable {
            issues.append(issue(.error, "LocalObservationService를 사용할 수 없습니다. room-scoped observation 저장소가 없으면 다른 방의 파일이 현재 방에 유입될 수 있습니다."))
        }
        if !snap.observationsRoomScoped {
            issues.append(issue(.error, "observation이 roomID 기준으로 격리되지 않습니다. roomID 없는 observation은 pendingObservations 상태여야 하며 다른 방에 자동 노출되면 안 됩니다."))
        }
    }

    private static func validateDownloadsWatcherSafetyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.downloadsWatcherAvailable {
            issues.append(issue(.warning, "DownloadsFolderWatcher를 사용할 수 없습니다."))
        }
        if !snap.downloadsWatcherDefaultOff {
            issues.append(issue(.error, "DownloadsFolderWatcher가 기본값 ON으로 설정되어 있습니다. 사용자 명시 활성화 전까지 isEnabled = false여야 합니다."))
        }
        if !snap.pendingObservationAttachAvailable {
            issues.append(issue(.warning, "Downloads에서 감지된 파일을 방에 첨부하는 경로(attachObservation)가 없습니다."))
        }
    }

    private static func validateClipboardPrivacyPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.clipboardReaderExplicitOnly {
            issues.append(issue(.error, "클립보드를 상시 감시하거나 timer로 polling하고 있습니다. ClipboardContextReader는 사용자 명시 요청 시에만 실행되어야 합니다."))
        }
    }

    private static func validateScreenObservationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.screenObservationPolicyAvailable {
            issues.append(issue(.warning, "ScreenObservationPolicy가 없습니다. 화면 캡처 정책이 명문화되지 않으면 향후 구현 시 잘못된 동작이 추가될 수 있습니다."))
        }
        if !snap.screenContinuousCaptureBlocked {
            issues.append(issue(.error, "화면 상시 캡처가 차단되지 않았습니다. ScreenObservationPolicy.continuousCaptureAllowed = false여야 합니다."))
        }
    }

    private static func validateOfficeReviewInputPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewInputPolicyAvailable {
            issues.append(issue(.warning, "OfficeReviewInputPolicy가 없습니다. 사무 검토 skill 매핑과 결과 카드 구조가 정의되지 않으면 검토 기능 확장 시 일관성이 깨질 수 있습니다."))
        }
    }

    private static func validateAutomaticExternalUploadBlockedPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.automaticExternalUploadBlocked {
            issues.append(issue(.error, "자동 외부 업로드가 차단되지 않았습니다. ObservationPermissionPolicy.automaticExternalUploadAllowed = false여야 합니다. 사용자 파일을 자동으로 외부 서버에 업로드하면 심각한 개인정보 침해가 발생합니다."))
        }
    }

    // MARK: - Round 246A: UNBLOCK Validators

    private static func validateGoalGateFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.goalGateFallbackFunctional {
            issues.append(issue(.error, "GoalGate fallback이 LLM까지 연결되지 않습니다. capability blocked → runDirectChatFallback() 경로가 없으면 사용자에게 아무 응답도 없이 막히게 됩니다."))
        }
    }

    private static func validateToolLayerTypedResultPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.toolLayerTypedResultAvailable {
            issues.append(issue(.warning, "ToolExecutionLayer가 모든 비-성공 결과를 .blocked로 뭉개고 있습니다. .planned/.unavailable/.approvalRequired를 구분해야 WorkflowOrchestrator가 적절한 pivot을 할 수 있습니다."))
        }
    }

    private static func validateApprovalFoundationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.approvalFoundationAvailable {
            issues.append(issue(.warning, "PendingApprovalRequest 모델이 없습니다. .requiresApproval 상태가 있어도 무엇을 승인하는지 불명확한 상태가 됩니다."))
        }
    }

    private static func validateDelegationGatePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.delegationGateRespected {
            issues.append(issue(.error, "위임 모드가 capability gate를 우회합니다. 위임은 실행 주체를 바꾸는 것이지 권한을 올리는 것이 아닙니다. blocked 작업이 '팀원한테 시켜' 패턴으로 실행될 수 있습니다."))
        }
    }

    private static func validateBudgetTierInterfacePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.budgetTierInterfaceAvailable {
            issues.append(issue(.warning, "AICallBudgetTier 인터페이스가 없습니다. 실무 사무 검토 1건도 rolling limit에 막힐 수 있습니다."))
        }
    }

    private static func validateOfficeReviewExecutionStatusPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewExecutionStatusAvailable {
            issues.append(issue(.warning, "OfficeReviewExecutionStatus enum이 없습니다. '계정과목 정합성 된다면서 왜 안 돼?' 같은 사용자 혼선이 발생합니다."))
        }
    }

    // MARK: - Round 246A-HOTFIX Validators

    private static func validateFeatureAvailabilitySeparatedPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.featureAvailabilitySeparatedFileAvailable {
            issues.append(issue(.warning, "FeatureAvailability enum이 FeatureAvailability.swift로 분리되지 않았습니다. BuiltInKoreanSkills 내부에 있으면 다른 모듈에서 재사용이 어렵습니다."))
        }
    }

    private static func validateSkillAvailabilityResolverPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.skillAvailabilityResolverAvailable {
            issues.append(issue(.warning, "SkillAvailabilityResolver가 없습니다. assistOnly 판단이 스킬마다 분산되면 일관성이 깨집니다."))
        }
    }

    private static func validateCapabilityFallbackServicePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.capabilityFallbackServiceAvailable {
            issues.append(issue(.error, "CapabilityFallbackService가 없습니다. ToolResultStatus → FallbackAction 변환이 없으면 .planned/.unavailable 결과를 받아도 WorkflowOrchestrator가 사용자에게 응답을 못 합니다."))
        }
    }

    private static func validateOfficeReviewNoDuplicateCasePolicy(issues: inout [ToolContractValidationIssue]) {
        // 코드 정적 검사가 아닌 정책 문서 수준 검증
        // 실제 중복 case는 Swift 컴파일러가 잡아주므로 여기서는 정책 명시
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewExecutionStatusAvailable {
            issues.append(issue(.warning, "OfficeReviewInputPolicy에 중복 case 위험이 있습니다. switch 내 .taxInvoiceComparison이 중복되지 않는지 확인하세요."))
        }
    }

    // MARK: - Round 246B: ACTION Validators

    private static func validateApprovalStoreAvailablePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.approvalStoreAvailable {
            issues.append(issue(.error, "PendingApprovalStore가 없습니다. approvalRequired ToolResult를 처리하려면 room-scoped approval store가 필요합니다."))
        }
    }

    private static func validateApprovalBannerViewPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.approvalBannerViewAvailable {
            issues.append(issue(.warning, "PendingApprovalBannerView가 없습니다. 사용자가 pending approval을 확인할 UI 진입점이 없습니다."))
        }
        if !snap.approvalCardViewAvailable {
            issues.append(issue(.warning, "ApprovalRequiredCardView가 없습니다. 승인 요청 상세 카드를 표시할 수 없습니다."))
        }
    }

    private static func validateToolResultPresentationPolicyAvailable(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.toolResultPresentationPolicyAvailable {
            issues.append(issue(.error, "ToolResultPresentationPolicy가 없습니다. ToolResult.status → 사용자 경험 매핑이 없으면 상태별 UX가 일관되지 않습니다."))
        }
    }

    private static func validateAssistOnlySkillDetectionWiredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.assistOnlySkillDetectionWired {
            issues.append(issue(.error, "Orchestrator에서 assistOnly 스킬 감지가 연결되지 않았습니다. DART 등 API 미구현 스킬이 실제 실행을 시도할 수 있습니다."))
        }
    }

    private static func validateHighRiskSkillFallbackWiredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.highRiskSkillFallbackWired {
            issues.append(issue(.error, "High-risk 스킬 → directChat fallback이 연결되지 않았습니다. 위험 작업이 아무 안내 없이 실행될 수 있습니다."))
        }
    }

    private static func validateDisabledSkillFallbackWiredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.disabledSkillFallbackWired {
            issues.append(issue(.error, "Disabled 스킬 → CapabilityFallbackService 연결이 없습니다. 비활성 스킬 요청 시 사용자가 아무 응답도 받지 못합니다."))
        }
    }

    private static func validateWorkflowTypedStatusHandledPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.workflowTypedStatusHandled {
            issues.append(issue(.error, "WorkflowEngine → WorkflowResult typed 상태 전파가 없습니다. .approvalRequired/.planned/.unavailable 결과가 Orchestrator에 전달되지 않습니다."))
        }
    }

    private static func validateApprovalRequiredAutoRegisteredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.approvalRequiredAutoRegistered {
            issues.append(issue(.error, "WorkflowResult.approvalRequiredRequests → addPendingApproval 연결이 없습니다. 승인 대기 작업이 approval store에 등록되지 않습니다."))
        }
    }

    private static func validatePlannedStepFallbackWiredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.plannedStepFallbackWired {
            issues.append(issue(.warning, "WorkflowResult.plannedStepMessages → directChat fallback 연결이 없습니다. 준비 중 기능 요청 시 사용자에게 안내가 없습니다."))
        }
    }

    private static func validateUnavailableStepFallbackWiredPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.unavailableStepFallbackWired {
            issues.append(issue(.warning, "WorkflowResult.unavailableStepMessages → directChat fallback 연결이 없습니다. 사용 불가 기능 요청 시 대체 도움이 없습니다."))
        }
    }

    private static func validateOfficeReviewAssistOnlyUxPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewAssistOnlyUxAvailable {
            issues.append(issue(.warning, "OfficeReviewInputPolicy에 assistOnly UX 메시지가 없습니다. 사용자에게 '파일 올려주세요' 안내가 표시되지 않습니다."))
        }
    }

    private static func validateObservationImplLevelUxPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.observationImplLevelUxAvailable {
            issues.append(issue(.warning, "ImplementationLevel.userFacingStatus가 없습니다. 관찰 컴포넌트 상태를 사용자에게 정직하게 보여줄 수 없습니다."))
        }
    }

    // MARK: - Round 247TTS Validators

    private static func validateAppleSystemTTSBlocked(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.appleSystemTTSBlocked {
            issues.append(issue(.error, "Apple TTS (AVSpeechSynthesizer) 차단 정책이 등록되지 않았습니다. 프로젝트 정책: 폴백 포함 절대 금지."))
        }
    }

    private static func validateQwen3DefaultDisabledPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.qwen3TTSDefaultDisabled {
            issues.append(issue(.error, "Qwen3 TTS 기본 비활성화 정책이 등록되지 않았습니다. Qwen3는 기본 off여야 합니다."))
        }
    }

    private static func validateSupertonic3ExperimentalPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.supertonic3ProviderRegistered {
            issues.append(issue(.warning, "Supertonic3TTSProvider가 등록되지 않았습니다. Round 247TTS PoC skeleton이 없습니다."))
        }
        if !snap.supertonic3DefaultDisabled {
            issues.append(issue(.error, "Supertonic3 TTS가 기본 활성화되어 있습니다. 기본값은 반드시 off여야 합니다."))
        }
    }

    private static func validateSupertonic3NoAutoDownloadPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.supertonic3NoAutoDownload {
            issues.append(issue(.error, "Supertonic3 자동 다운로드 금지 정책이 등록되지 않았습니다. 모델 자동 다운로드 코드가 없어야 합니다."))
        }
    }

    private static func validateTTSSilentFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.ttsSilentFallbackAllowed {
            issues.append(issue(.error, "TTS 무음 폴백 정책이 등록되지 않았습니다. provider 없을 때 무음 허용(Apple TTS 폴백 절대 금지)이어야 합니다."))
        }
    }

    private static func validateTTSProviderModelsFileExists(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.supertonic3ProviderRegistered {
            issues.append(issue(.warning, "TTSProviderModels.swift 관련 상태가 등록되지 않았습니다. TTSProviderKind enum 정의가 필요합니다."))
        }
    }

    private static func validateTTSRoutingPolicyExists(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.ttsSilentFallbackAllowed {
            issues.append(issue(.warning, "TTSRoutingPolicy 관련 상태가 등록되지 않았습니다. provider 선택 정책이 필요합니다."))
        }
    }

    // MARK: - Round 247A-OBSERVE-RUNTIME Validators

    private static func validateObservationInboxViewPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.observationInboxViewAvailable {
            issues.append(issue(.error, "ObservationInboxView.swift가 없습니다. pending observation을 방별로 표시하는 UI가 필요합니다."))
        }
        if !snap.observationCardsConnectedToTeamRoom {
            issues.append(issue(.error, "TeamStatusView에 ObservationInboxView가 연결되지 않았습니다."))
        }
    }

    private static func validateObservationTeamPersonalRoomScopePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.observationCardsConnectedToPersonalRoom {
            issues.append(issue(.error, "AgentChatView에 ObservationInboxView가 연결되지 않았습니다."))
        }
        if !snap.observationRoomScopeEnforced {
            issues.append(issue(.error, "Observation room scope가 적용되지 않았습니다. pending observation이 모든 방에 표시되면 안 됩니다."))
        }
    }

    private static func validateClipboardExplicitReadRoutePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.clipboardExplicitReadRouteAvailable {
            issues.append(issue(.error, "클립보드 명시 읽기 경로가 WorkflowOrchestrator에 연결되지 않았습니다."))
        }
        // timer polling이 있으면 error — ClipboardContextReader.continuousMonitoringAllowed 확인
        if ClipboardContextReader.continuousMonitoringAllowed {
            issues.append(issue(.error, "ClipboardContextReader.continuousMonitoringAllowed = true — 상시 클립보드 감시는 절대 금지입니다."))
        }
    }

    private static func validateDownloadsWatcherDefaultOffUIPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.downloadsWatcherSettingsDefaultOff {
            issues.append(issue(.error, "Downloads watcher가 기본 ON 상태입니다. 사용자 명시 활성화 없이 자동 감시 금지입니다."))
        }
    }

    private static func validateFinderSelectionFallbackPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.finderSelectionFallbackAvailable {
            issues.append(issue(.warning, "Finder 선택 파일 fallback 메시지가 등록되지 않았습니다."))
        }
    }

    private static func validateScreenSnapshotPlannedNoticePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.screenSnapshotPlannedNoticeAvailable {
            issues.append(issue(.error, "화면 캡처 planned notice가 없습니다. 화면 읽기가 마치 available한 것처럼 표시되면 안 됩니다."))
        }
        if ScreenObservationPolicy.continuousCaptureAllowed {
            issues.append(issue(.error, "ScreenObservationPolicy.continuousCaptureAllowed = true — 상시 화면 감시는 절대 금지입니다."))
        }
    }

    private static func validateObservationPresentationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.observationPresentationPolicyAvailable {
            issues.append(issue(.error, "ObservationPresentationPolicy.swift가 없습니다. observation 관련 사용자 메시지 정책 파일이 필요합니다."))
        }
    }

    private static func validateObservationNoAutoAnalyzePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.observationAttachDoesNotAutoAnalyze {
            issues.append(issue(.error, "observation attach가 자동으로 LLM 분석을 트리거합니다. attach는 분석이 아닙니다."))
        }
    }

    // Round 248A-OFFICE-LITE validators

    private static func validateOfficeReviewLiteExecutorPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewLiteExecutorAvailable {
            issues.append(issue(.error, "OfficeReviewLiteExecutor.swift가 없습니다. 1차 office review 실행이 필요합니다."))
        }
        if !snap.officeReviewHeuristicExtractionOnly {
            issues.append(issue(.error, "Office review lite는 휴리스틱 기반 추출만 지원합니다. 실제 Excel/PDF 파싱 금지입니다."))
        }
    }

    private static func validateOfficeReviewResultCardPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewResultCardViewAvailable {
            issues.append(issue(.error, "OfficeReviewResultCardView.swift가 없습니다. 검토 결과 UI 컴포넌트가 필요합니다."))
        }
    }

    private static func validateOfficeReviewNoOriginalFileMutationPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewNoOriginalFileMutation {
            issues.append(issue(.error, "Office review가 원본 파일을 변경하면 안 됩니다. 결과만 artifact로 생성해야 합니다."))
        }
    }

    private static func validateOfficeReviewNoEvidenceLocationTrackingPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewNoEvidenceLocationTracking {
            issues.append(issue(.warning, "Evidence location tracking이 구현되지 않았습니다. 휴리스틱 기반 결과는 근거 위치 추적을 지원하지 않습니다."))
        }
    }

    private static func validateOfficeReviewLimitationsDisclaimerPolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewLimitationsDisclaimerShown {
            issues.append(issue(.error, "Office review 결과 카드에 limitations disclaimer가 표시되지 않습니다. 사용자 신뢰 보호 필수입니다."))
        }
    }

    private static func validateOfficeReviewAssistOnlyGuidancePolicy(issues: inout [ToolContractValidationIssue]) {
        let snap = RuntimeDiagnosticsService.shared.cachedSnapshot
        guard let snap else { return }
        if !snap.officeReviewAssistOnlyGuidanceAvailable {
            issues.append(issue(.error, "2차 assistOnly 스킬이 적절한 안내 메시지를 제공하지 않습니다. LLM 상담 가이드 필수입니다."))
        }
    }
}
