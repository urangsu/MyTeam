import Foundation

// MARK: - SkillValidationError

enum SkillValidationError: Error, LocalizedError {
    case emptyField(String)
    case emptyTriggers
    case emptyPromptTemplate
    case emptyScopeList
    case highRiskRequiresApproval
    case highRiskRequiresDisabledByDefault
    case unknownWorkflowTool(String)
    case invalidID(String)

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "필드가 비어 있습니다: \(field)"
        case .emptyTriggers:
            return "triggers가 비어 있습니다."
        case .emptyPromptTemplate:
            return "promptTemplate이 비어 있습니다."
        case .emptyScopeList:
            return "allowedScopes가 비어 있습니다."
        case .highRiskRequiresApproval:
            return "high-risk 스킬은 requiresApprovalEveryRun=true이어야 합니다."
        case .highRiskRequiresDisabledByDefault:
            return "high-risk 스킬(reservation/payment/accountLogin)은 defaultEnabled=false이어야 합니다."
        case .unknownWorkflowTool(let toolName):
            return "workflowTemplate 에 등록되지 않은 도구: \(toolName)"
        case .invalidID(let reason):
            return "스킬 ID 형식 오류: \(reason)"
        }
    }
}

// MARK: - SkillRegistry

final class SkillRegistry {
    static let shared = SkillRegistry()

    private var skills: [String: SkillManifest] = [:]

    private init() {
        BuiltInKoreanSkills.all.forEach { register($0) }
        AppLog.info("[SkillRegistry] 초기화 완료: built-in \(skills.count)개 등록")
    }

    // MARK: - Register (private — 외부 직접 등록 금지)

    private func register(_ skill: SkillManifest) {
        do {
            try validateSkill(skill)
            skills[skill.id] = skill
        } catch {
            AppLog.error("[SkillRegistry] 등록 실패 '\(skill.id)': \(error.localizedDescription)")
        }
    }

    // MARK: - Queries

    func builtInSkills() -> [SkillManifest] {
        skills.values.filter { $0.isBuiltIn }.sorted { $0.id < $1.id }
    }

    /// 사용자 설치 스킬 — Round 7에서 UserSkillStore 연동
    func userSkills() -> [SkillManifest] { [] }

    /// built-in + user 스킬을 읽기 전용으로 합쳐서 반환한다.
    var allSkillManifests: [SkillManifest] {
        (builtInSkills() + userSkills()).sorted { $0.id < $1.id }
    }

    /// 특정 스킬 ID를 read-only로 조회한다.
    func skill(named id: String) -> SkillManifest? {
        skills[id]
    }

    func allEnabledSkills() -> [SkillManifest] {
        skills.values.filter { isSkillEnabled(id: $0.id) }.sorted { $0.id < $1.id }
    }

    // MARK: - Skill Match

    /// 메시지 텍스트에 트리거 키워드가 포함된 활성화 스킬을 반환한다.
    func matchEnabledSkills(for message: String) -> [SkillManifest] {
        let lower = message.lowercased()
        return allEnabledSkills().filter { skill in
            skill.triggers.contains { lower.contains($0.lowercased()) }
        }
    }

    /// 메시지 텍스트에 트리거 키워드가 포함된 모든 스킬(활성화/비활성화)을 반환한다.
    func matchAllSkills(for message: String) -> [SkillManifest] {
        let lower = message.lowercased()
        return skills.values.filter { skill in
            skill.triggers.contains { lower.contains($0.lowercased()) }
        }.sorted { $0.id < $1.id }
    }

    // MARK: - Helpers

    /// Skill ID whitelist 검증: a-z A-Z 0-9 . _ - 만 허용
    nonisolated static func isValidSkillID(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        let allowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let hasOnlyAllowed = id.allSatisfy { $0.unicodeScalars.allSatisfy { allowedChars.contains($0) } }
        return hasOnlyAllowed && !id.contains("..")
    }

    /// High-risk skill 판별: riskLevel 또는 requiredPermissions 기반
    nonisolated static func isHighRiskSkill(_ skill: SkillManifest) -> Bool {
        let highRiskLevels: Set<SkillRiskLevel> = [.personalData, .accountLogin, .externalWrite, .reservation, .payment, .regulated]
        if highRiskLevels.contains(skill.riskLevel) { return true }

        let dangerousPermissions: Set<SkillPermission> = [
            .requiresUserLogin, .readsPersonalData, .sendsMessage, .makesReservation,
            .handlesPayment, .financialData, .browserAutomation, .officeLive
        ]
        return skill.requiredPermissions.contains { dangerousPermissions.contains($0) }
    }

    // MARK: - Validation

    func validateSkill(_ skill: SkillManifest) throws {
        // Rule 1: 필수 문자열 필드 비어 있으면 실패
        if skill.id.isEmpty      { throw SkillValidationError.emptyField("id") }
        if skill.name.isEmpty    { throw SkillValidationError.emptyField("name") }
        if skill.version.isEmpty { throw SkillValidationError.emptyField("version") }

        // Rule 1-1: id whitelist 검증
        guard Self.isValidSkillID(skill.id) else {
            throw SkillValidationError.invalidID("a-z, A-Z, 0-9, '.', '-', '_' 만 허용. 금지: '/', '\\\\', '..', 공백")
        }

        // Rule 2: triggers 비어 있으면 실패
        if skill.triggers.isEmpty { throw SkillValidationError.emptyTriggers }

        // Rule 3: promptTemplate 비어 있으면 실패
        if skill.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SkillValidationError.emptyPromptTemplate
        }

        // Rule 4: allowedScopes 비어 있으면 실패
        if skill.allowedScopes.isEmpty { throw SkillValidationError.emptyScopeList }

        // Rule 5: personalData/reservation/payment/accountLogin → requiresApprovalEveryRun=true 필요
        let approvalRequiredLevels: Set<SkillRiskLevel> = [.personalData, .reservation, .payment, .accountLogin]
        if approvalRequiredLevels.contains(skill.riskLevel) && !skill.requiresApprovalEveryRun {
            throw SkillValidationError.highRiskRequiresApproval
        }

        // Rule 6: reservation/payment/accountLogin → defaultEnabled=false 필요
        let defaultOffRequired: Set<SkillRiskLevel> = [.reservation, .payment, .accountLogin]
        if defaultOffRequired.contains(skill.riskLevel) && skill.defaultEnabled {
            throw SkillValidationError.highRiskRequiresDisabledByDefault
        }

        // Rule 7: workflowTemplate 내 toolName은 ToolRegistry에 존재해야 함
        if let template = skill.workflowTemplate {
            for toolName in template {
                guard ToolRegistry.shared.lookup(name: toolName) != nil else {
                    throw SkillValidationError.unknownWorkflowTool(toolName)
                }
            }
        }
    }

    // MARK: - Enable/Disable (UserDefaults 영속화)

    /// key: "skill.enabled.<id>"
    /// 키 미설정 시 defaultEnabled 폴백 — bool(forKey:) 단독 사용 금지
    /// (false=미설정과 false=명시비활성을 구분하기 위해 object(forKey:) 체크 필요)
    func isSkillEnabled(id: String) -> Bool {
        let key = "skill.enabled.\(id)"
        if UserDefaults.standard.object(forKey: key) == nil {
            return skills[id]?.defaultEnabled ?? false
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setSkillEnabled(id: String, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "skill.enabled.\(id)")
    }
}
