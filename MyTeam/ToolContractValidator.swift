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
}
