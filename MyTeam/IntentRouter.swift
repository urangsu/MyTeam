import Foundation

// MARK: - IntentRouter
// 사용자의 입력을 분석하여 '수다' 혹은 '업무'로 분류하고 적절한 리더를 추천한다.

enum UserIntent: String, Codable {
    case chitchat = "CHITCHAT"  // 단순 인사, 농담, 리액션 등
    case quickAnswer = "QUICK_ANSWER" // 짧은 사실 답변, 가벼운 확인
    case task = "TASK"          // 리서치, 분석, 작업, 도구 사용 등 업무 지시
    case research = "RESEARCH"  // 최신 정보/외부 근거가 필요한 조사
    case decision = "DECISION"  // 장단점 비교와 추천이 필요한 판단
}

enum ResponseDepth: String, Codable {
    case short = "SHORT"
    case normal = "NORMAL"
    case deep = "DEEP"
}

enum RiskLevel: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

struct AgentWorkOrder: Codable {
    let agentID: String
    let subTask: String           // 에이전트가 수행할 구체적인 하위 작업

    // AgentPipeline 용 확장 필드 — IntentRouter JSON은 기존 필드만 있어도 된다.
    let role: AgentRole?
    let title: String?
    let instruction: String?
    let inputKeys: [String]?
    let outputKey: String?
    let verificationLevel: VerificationLevel?
    let maxRetries: Int?
}

struct IntentResult: Codable {
    let intent: UserIntent
    let taskCategory: String?       // 개발, 기획, 디자인, 분석 등
    let workOrders: [AgentWorkOrder]? // 시스템 팀장이 하달하는 상세 지시서 목록
    let proactiveMessage: String?   // (에러 방지용) 에이전트가 주도적으로 제안하는 멘트
    let responseDepth: ResponseDepth?
    let turnBudget: Int?
    let needsTool: Bool?
    let needsWeb: Bool?
    let riskLevel: RiskLevel?
    let requiresFinalSummary: Bool?
}

class IntentRouter {
    static let shared = IntentRouter()
    
    /// 사용자의 메시지와 현재 활성화된 에이전트 목록을 바탕으로 의도를 분류한다.
    func classify(
        message: String,
        activeAgents: [AgentWindowManager.AgentConfig],
        leaderAgent: AgentWindowManager.AgentConfig? = nil,
        addressedAgent: AgentWindowManager.AgentConfig? = nil,
        unavailableMentionedAgent: AgentWindowManager.AgentConfig? = nil,
        toolPolicy: ToolPolicyDecision? = nil
    ) async throws -> IntentResult {
        let resolvedToolPolicy = toolPolicy ?? ToolPolicy.evaluate(message)
        
        let agentContext = activeAgents.map { "- \($0.id): \($0.name) (\($0.role))" }.joined(separator: "\n")
        let leaderContext: String
        if let leaderAgent {
            leaderContext = "\(leaderAgent.id): \(leaderAgent.name) (\(leaderAgent.role))"
        } else {
            leaderContext = "미지정. 현재 팀의 첫 번째 에이전트를 임시 진행자로 사용."
        }
        let mentionContext: String
        if let addressedAgent {
            mentionContext = "사용자가 '\(addressedAgent.name)'을 직접 불렀습니다. 가능하면 첫 응답 또는 첫 작업 지시를 이 에이전트에게 배정하세요."
        } else if let unavailableMentionedAgent {
            mentionContext = "사용자가 '\(unavailableMentionedAgent.name)'을 직접 불렀지만 현재 팀에 없습니다. 팀 리더가 부재를 짧게 알리고 대신 진행해야 합니다."
        } else {
            mentionContext = "직접 지명된 캐릭터 없음."
        }
        
        let systemPrompt = """
        당신은 고도로 지능적인 시스템 오케스트레이터(System Orchestrator)입니다.
        사용자의 메시지를 분석하여 팀 리더가 진행할 대화 운영안과 실무 작업 지시서를 JSON 형식으로 생성하세요.
        
        [에이전트 목록]
        \(agentContext)

        [사용자가 지정한 팀 리더]
        \(leaderContext)

        [사용자 직접 지명]
        \(mentionContext)

        [도구 정책 판단]
        \(resolvedToolPolicy.promptSummary)
        
        [JSON 형식]
        {
          "intent": "CHITCHAT" 또는 "QUICK_ANSWER" 또는 "TASK" 또는 "RESEARCH" 또는 "DECISION",
          "taskCategory": "분석/기획/코딩/디자인 등",
          "workOrders": [
             { "agentID": "에이전트ID", "subTask": "구체적인 수행 지침" }
          ],
          "proactiveMessage": "팀 리더가 회의를 여는 짧은 첫 멘트",
          "responseDepth": "SHORT" 또는 "NORMAL" 또는 "DEEP",
          "turnBudget": 1,
          "needsTool": false,
          "needsWeb": false,
          "riskLevel": "LOW" 또는 "MEDIUM" 또는 "HIGH",
          "requiresFinalSummary": false
        }
        
        [지침]
        1. 단순 인사와 감정 리액션은 CHITCHAT, 짧은 사실 답변은 QUICK_ANSWER로 분류하세요.
        2. 복합적인 작업인 경우, 최대 3명의 에이전트에게 순차적인 workOrders를 부여할 수 있습니다.
        3. 각 에이전트의 [role]을 고려하여 가장 완벽한 전문가 조합을 구성하세요.
        4. 사용자가 지정한 팀 리더는 회의 진행자입니다. 첫 멘트와 최종 정리는 가능하면 리더가 맡게 하세요.
        5. 실제 전문 답변은 리더가 아니라도 가장 적합한 에이전트에게 배정하세요.
        6. 최신 정보, 가격, 뉴스, 웹페이지 확인이 필요하면 needsWeb을 true로 설정하세요.
        7. 법률/보안/결제/개인정보/출시 판단은 riskLevel을 MEDIUM 이상으로 설정하고 requiresFinalSummary를 true로 설정하세요.
        8. 사용자가 현재 팀에 있는 캐릭터 이름을 직접 부르면, 그 캐릭터가 먼저 말하거나 첫 workOrder를 맡도록 우선권을 주세요.
        9. 도구 정책의 needsFinance가 true이면 RESEARCH로 분류하고, 투자 조언처럼 단정하지 말고 시세/뉴스/실적 출처 확인이 필요하다고 판단하세요.
        10. 도구 정책의 recommendedTools에 포함된 도구가 있으면 needsTool을 true로 설정하세요.
        """
        
        // AIService를 통해 JSON 응답 강제 (SSE 스트림을 collect하여 반환)
        let (rawJSON, _) = try await AIService.shared.getResponse(
            text: "\(systemPrompt)\n\n[사용자 메시지]: \(message)",
            agentID: "system_router",
            chatHistory: []
        )
        
        // JSON 파싱 (안정성을 위해 앞뒤 찌꺼기 제거)
        let cleanedJSON = cleanJSON(rawJSON)
        guard let data = cleanedJSON.data(using: String.Encoding.utf8) else {
            return IntentResult.fallback
        }
        
        do {
            let result = try JSONDecoder().decode(IntentResult.self, from: data)
            return result
        } catch {
            print("IntentRouter Parsing Error: \(error). Falling back to CHITCHAT.")
            return IntentResult.fallback
        }
    }
    
    private func cleanJSON(_ text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[start...end])
    }
}

extension IntentResult {
    static let fallback = IntentResult(
        intent: .chitchat,
        taskCategory: nil,
        workOrders: nil,
        proactiveMessage: nil,
        responseDepth: .short,
        turnBudget: 2,
        needsTool: false,
        needsWeb: false,
        riskLevel: .low,
        requiresFinalSummary: false
    )
}
