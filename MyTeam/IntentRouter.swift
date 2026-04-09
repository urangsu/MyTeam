import Foundation

// MARK: - IntentRouter
// 사용자의 입력을 분석하여 '수다' 혹은 '업무'로 분류하고 적절한 리더를 추천한다.

enum UserIntent: String, Codable {
    case chitchat = "CHITCHAT"  // 단순 인사, 농담, 리액션 등
    case task = "TASK"          // 리서치, 분석, 작업, 도구 사용 등 업무 지시
}

struct AgentWorkOrder: Codable {
    let agentID: String
    let subTask: String           // 에이전트가 수행할 구체적인 하위 작업
}

struct IntentResult: Codable {
    let intent: UserIntent
    let taskCategory: String?       // 개발, 기획, 디자인, 분석 등
    let workOrders: [AgentWorkOrder]? // 시스템 팀장이 하달하는 상세 지시서 목록
    let proactiveMessage: String?   // (에러 방지용) 에이전트가 주도적으로 제안하는 멘트
}

class IntentRouter {
    static let shared = IntentRouter()
    
    /// 사용자의 메시지와 현재 활성화된 에이전트 목록을 바탕으로 의도를 분류한다.
    func classify(
        message: String,
        activeAgents: [AgentWindowManager.AgentConfig]
    ) async throws -> IntentResult {
        
        let agentContext = activeAgents.map { "- \($0.id): \($0.name) (\($0.role))" }.joined(separator: "\n")
        
        let systemPrompt = """
        당신은 고도로 지능적인 시스템 오케스트레이터(System Orchestrator)입니다.
        사용자의 메시지를 분석하여 실무를 수행할 에이전트들에게 하달할 '작업 지시서'를 JSON 형식으로 생성하세요.
        
        [에이전트 목록]
        \(agentContext)
        
        [JSON 형식]
        {
          "intent": "CHITCHAT" 또는 "TASK",
          "taskCategory": "분석/기획/코딩/디자인 등",
          "workOrders": [
             { "agentID": "에이전트ID", "subTask": "구체적인 수행 지침" }
          ],
          "proactiveMessage": "첫 번째 수행 에이전트의 성격으로 '이건 제 전문이죠, 진행할게요!' 식의 짧은 제안 멘트"
        }
        
        [지침]
        1. 단순 인사는 CHITCHAT으로 분류하고 workOrders는 null로 하세요.
        2. 복합적인 작업인 경우, 최대 2명의 에이전트에게 순차적인 workOrders를 부여할 수 있습니다.
        3. 각 에이전트의 [role]을 고려하여 가장 완벽한 전문가 조합을 구성하세요.
        4. proactiveMessage는 반드시 첫 번째 에이전트의 성격(Persona)을 반영하세요.
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
            return IntentResult(intent: .chitchat, taskCategory: nil, workOrders: nil, proactiveMessage: nil)
        }
        
        do {
            let result = try JSONDecoder().decode(IntentResult.self, from: data)
            return result
        } catch {
            print("IntentRouter Parsing Error: \(error). Falling back to CHITCHAT.")
            return IntentResult(intent: .chitchat, taskCategory: nil, workOrders: nil, proactiveMessage: nil)
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
