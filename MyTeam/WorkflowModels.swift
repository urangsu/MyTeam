import Foundation

// MARK: - WorkflowPlan

struct WorkflowPlan: Codable {
    let title: String
    let steps: [WorkflowStep]
}

// MARK: - WorkflowStep

struct WorkflowStep: Codable {
    let id: String               // UUID 문자열
    let toolName: String
    let title: String
    let input: [String: String]
    let isRequired: Bool         // true → 실패 시 workflow 전체 중단
    let dependsOn: [String]      // 선행 step ID (MVP에서는 순차 실행이므로 참조만)
    let riskLevel: ToolRiskLevel

    enum CodingKeys: String, CodingKey {
        case id, toolName, title, input, isRequired, dependsOn, riskLevel
    }

    // LLM이 일부 필드를 생략해도 기본값 적용
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decode(String.self,           forKey: .id))         ?? UUID().uuidString
        toolName   = try  c.decode(String.self,            forKey: .toolName)
        title      = try  c.decode(String.self,            forKey: .title)
        input      = (try? c.decode([String: String].self, forKey: .input))      ?? [:]
        isRequired = (try? c.decode(Bool.self,             forKey: .isRequired)) ?? true
        dependsOn  = (try? c.decode([String].self,         forKey: .dependsOn))  ?? []
        riskLevel  = (try? c.decode(ToolRiskLevel.self,    forKey: .riskLevel))  ?? .moderate
    }
}

// MARK: - Artifact

struct Artifact {
    let stepID: String
    let stepTitle: String
    let path: String      // Workspace 상대 경로
    let output: String    // 요약 텍스트
}

// MARK: - WorkflowResult

struct WorkflowResult {
    let plan: WorkflowPlan
    let artifacts: [Artifact]
    let failedSteps: [(step: WorkflowStep, error: String)]
    let summary: String
}
