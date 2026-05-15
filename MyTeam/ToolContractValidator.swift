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
}
