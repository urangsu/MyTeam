import Foundation

// MARK: - SkillCategory

enum SkillCategory: String, Codable {
    case koreanLife
    case koreanBusiness
    case koreanGovernment
    case koreanFinance
    case koreanLegal
    case koreanMobility
    case koreanShopping
    case koreanWriting
    case koreanSports
    case document
    case diagnostics
}

// MARK: - SkillPermission

enum SkillPermission: String, Codable {
    case readWorkspaceFile
    case writeWorkspaceFile
    case createArtifact
    case usePublicWeb
    case usePublicAPI
    case useLocation
    case useKoreanPublicData
    case useWebEvidence
    case scheduleTask
    case diagnosticsRead
    case externalOpen
    case officeLive
    case browserAutomation
    case requiresUserLogin
    case readsPersonalData
    case sendsMessage
    case makesReservation
    case handlesPayment
    case financialData
    case legalOrAdministrative
    case healthOrDrugInfo
}

// MARK: - SkillRiskLevel
// Note: SkillRiskLevel은 ToolRiskLevel(AgentTool.swift)과 별개 타입이다.
// ToolRiskLevel은 WorkflowTool 실행 시 차단 여부를 결정하는 기술 레벨.
// SkillRiskLevel은 사용자 권한 / 승인 요구사항을 나타내는 정책 레벨.

enum SkillRiskLevel: String, Codable {
    case safeReadOnly    // 읽기 전용, 외부 부작용 없음
    case publicData      // 공개 API/웹 조회
    case personalData    // 개인 파일/데이터 처리
    case accountLogin    // 외부 계정 로그인 필요
    case externalWrite   // 외부 서비스에 쓰기
    case reservation     // 실제 예약 수반
    case payment         // 실제 결제 수반
    case regulated       // 금융·의료·법률 규제 영역
}

// MARK: - SkillOutputType

enum SkillOutputType: String, Codable {
    case chat
    case markdown
    case report
    case presentationPlan
    case spreadsheetPlan
    case artifact
    case externalResult
}

// MARK: - SkillManifest
// struct 본문 내 custom init을 정의해 synthesized memberwise init을 억제한다.
// optional 필드(workflowTemplate, sourceURL, backendHint, notes)에 nil 기본값 부여.

struct SkillManifest: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let version: String
    let description: String
    let locale: String
    let category: SkillCategory
    let triggers: [String]
    let allowedScopes: [ToolScope]
    let requiredPermissions: [SkillPermission]
    let requiredLogin: Bool
    let riskLevel: SkillRiskLevel
    let promptTemplate: String
    let outputType: SkillOutputType
    let workflowTemplate: [String]?
    let sourceURL: String?
    let isBuiltIn: Bool
    let defaultEnabled: Bool
    let requiresApprovalEveryRun: Bool
    /// 미래 백엔드 연동 힌트 (예: "korean-law-mcp", "dart-open-api")
    let backendHint: String?
    /// 법적 고지, 정책 메모 등
    let notes: [String]?

    // 본문 init — synthesized memberwise init 억제 + optional 필드 기본값 nil 제공
    init(
        id: String,
        name: String,
        version: String,
        description: String,
        locale: String,
        category: SkillCategory,
        triggers: [String],
        allowedScopes: [ToolScope],
        requiredPermissions: [SkillPermission],
        requiredLogin: Bool,
        riskLevel: SkillRiskLevel,
        promptTemplate: String,
        outputType: SkillOutputType,
        workflowTemplate: [String]? = nil,
        sourceURL: String? = nil,
        isBuiltIn: Bool,
        defaultEnabled: Bool,
        requiresApprovalEveryRun: Bool,
        backendHint: String? = nil,
        notes: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.locale = locale
        self.category = category
        self.triggers = triggers
        self.allowedScopes = allowedScopes
        self.requiredPermissions = requiredPermissions
        self.requiredLogin = requiredLogin
        self.riskLevel = riskLevel
        self.promptTemplate = promptTemplate
        self.outputType = outputType
        self.workflowTemplate = workflowTemplate
        self.sourceURL = sourceURL
        self.isBuiltIn = isBuiltIn
        self.defaultEnabled = defaultEnabled
        self.requiresApprovalEveryRun = requiresApprovalEveryRun
        self.backendHint = backendHint
        self.notes = notes
    }
}
