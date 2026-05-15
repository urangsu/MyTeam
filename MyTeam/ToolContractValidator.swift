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
        for tool in tools {
            if tool.scope == .connectorRead {
                if tool.plannerVisible && !FeatureFlags.debugToolVisible {
                    issues.append(issue(.warning, "connector read tool '\(tool.name)' 이 Release planner-visible surface에 노출되었습니다."))
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

    private static func issue(_ severity: ToolContractValidationIssue.Severity, _ message: String) -> ToolContractValidationIssue {
        ToolContractValidationIssue(id: UUID(), severity: severity, message: message)
    }
}
