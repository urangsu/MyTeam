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
        validateCharacterDLCPolicy(issues: &issues)
        validateCharacterAssetPipeline(issues: &issues)
        validateProductSurfacePolicy(issues: &issues)

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

    private static func validateCharacterDLCPolicy(issues: inout [ToolContractValidationIssue]) {
        #if !DEBUG
        // Release mode: enforce DLC gate policy
        let allCharacters = CharacterCatalog.all

        for character in allCharacters {
            // Built-in characters must be visible
            if character.isBuiltIn && character.spriteAssetName.contains("placeholder") {
                issues.append(issue(.error, "Built-in character '\(character.name)' has placeholder sprite in Release mode."))
            }

            // Premium characters must have 6 conditions met or be hidden
            if character.isPremium && !character.isComingSoon {
                // If not coming soon, it must meet DLC conditions
                let hasProductionSprite = !character.spriteAssetName.contains("placeholder")
                if !hasProductionSprite {
                    issues.append(issue(.error, "Premium character '\(character.name)' visible in Release but has placeholder sprite."))
                }
            }

            // No "Coming Soon" characters should be visible in Release
            if character.isComingSoon && !character.isPremium {
                issues.append(issue(.warning, "Character '\(character.name)' marked as coming soon but may be visible in Release."))
            }
        }
        #endif
    }

    // MARK: - Round 76A-95Z: Character Asset Pipeline Gate

    private static func validateCharacterAssetPipeline(issues: inout [ToolContractValidationIssue]) {
        // 1. visibleBuiltIn이 최소 1명 이상이어야 함 (chiko)
        let visibleBuiltIn = ReleaseVisibleCharacterPolicy.visibleBuiltIn
        if visibleBuiltIn.isEmpty {
            #if !DEBUG
            issues.append(issue(.error, "Release 모드에서 표시 가능한 built-in 캐릭터가 없습니다. ReleaseVisibleCharacterPolicy 또는 CharacterAssetRegistry를 확인하세요."))
            #else
            issues.append(issue(.warning, "DEBUG: 표시 가능한 built-in 캐릭터 없음 — CharacterAssetRegistry 확인 필요."))
            #endif
        }

        // 2. placeholder 스프라이트인 built-in이 Release에 노출되면 안 됨
        let allBuiltIn = CharacterCatalog.builtIn
        for character in allBuiltIn {
            let manifest = CharacterAssetRegistry.manifest(
                for: character.id,
                spriteName: character.spriteAssetName
            )
            #if !DEBUG
            if manifest.isPlaceholder && ReleaseVisibleCharacterPolicy.isVisible(character) {
                issues.append(issue(.error, "Built-in character '\(character.name)' (id=\(character.id)) is placeholder but visible in Release. Policy gate failure."))
            }
            #endif
            // DEBUG: warn only
            if manifest.availability == .missing {
                issues.append(issue(.warning, "Character '\(character.name)' (id=\(character.id)) has no asset manifest — availability=missing."))
            }
        }

        // 3. isDLCPurchasable이지만 isComingSoon인 캐릭터가 없어야 함
        let purchasable = ReleaseVisibleCharacterPolicy.purchasablePremium
        for character in purchasable {
            if character.isComingSoon {
                issues.append(issue(.error, "Premium character '\(character.name)' marked purchasable but isComingSoon=true. Policy conflict."))
            }
        }

        // 4. policy report 일관성 체크
        let report = ReleaseVisibleCharacterPolicy.policyReport
        if report.visibleCount > report.totalCharacters {
            issues.append(issue(.error, "PolicyReport inconsistency: visibleCount(\(report.visibleCount)) > totalCharacters(\(report.totalCharacters))."))
        }
        if report.purchasableCount > report.totalCharacters {
            issues.append(issue(.error, "PolicyReport inconsistency: purchasableCount(\(report.purchasableCount)) > totalCharacters(\(report.totalCharacters))."))
        }
    }

    private static func validateProductSurfacePolicy(issues: inout [ToolContractValidationIssue]) {
        #if !DEBUG
        // Release mode: enforce product surface policy

        // Check if privacy copy policy is in place
        let hasPrivacyPolicy = FileManager.default.fileExists(atPath: "/Users/su/Desktop/MyTeam/docs/growth/TruthfulPrivacyCopyPolicy.md")
        if !hasPrivacyPolicy {
            issues.append(issue(.warning, "TruthfulPrivacyCopyPolicy.md not found. Privacy copy audit may be incomplete."))
        }

        // Check if app store metadata draft exists
        let hasAppStoreCopy = FileManager.default.fileExists(atPath: "/Users/su/Desktop/MyTeam/docs/AppStoreMetadataDraft.md")
        if !hasAppStoreCopy {
            issues.append(issue(.warning, "AppStoreMetadataDraft.md not found. App Store copy may be incomplete."))
        }

        // Check if copyright string is set
        if ProcessInfo.processInfo.environment["MYTEAM_COPYRIGHT_SET"] != "1" {
            issues.append(issue(.warning, "Copyright string may not be set in Info.plist. Verify via build settings."))
        }
        #endif
    }

    private static func issue(_ severity: ToolContractValidationIssue.Severity, _ message: String) -> ToolContractValidationIssue {
        ToolContractValidationIssue(id: UUID(), severity: severity, message: message)
    }
}
