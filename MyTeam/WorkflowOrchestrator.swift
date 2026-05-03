import Foundation

// MARK: - WorkflowOrchestrator
// TeamStatusView.sendTeamMessage()의 단일 진입점.
// IntentRouter 결과에 따라 TeamOrchestrator(수다) 또는 WorkflowEngine(업무)으로 라우팅한다.

final class WorkflowOrchestrator {
    static let shared = WorkflowOrchestrator()
    private init() {}

    func dispatch(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async {
        let intent = await classifyIntent(message: userMessage, manager: manager)
        AppLog.info("[WorkflowOrchestrator] Intent: \(intent.rawValue)")

        switch intent {
        case .chitchat, .quickAnswer:
            await TeamOrchestrator.shared.runTeamDiscussion(
                userMessage: userMessage,
                roomID: roomID,
                manager: manager
            )
        case .task, .research, .decision:
            await runWorkflow(userMessage: userMessage, roomID: roomID, manager: manager)
        }
    }

    // MARK: - Private

    private func classifyIntent(
        message: String,
        manager: AgentWindowManager
    ) async -> UserIntent {
        do {
            let result = try await IntentRouter.shared.classify(
                message: message,
                activeAgents: manager.activeAgents
            )
            return result.intent
        } catch {
            AppLog.warning("[WorkflowOrchestrator] IntentRouter 실패, chitchat으로 폴백: \(error)")
            return .chitchat
        }
    }

    private func runWorkflow(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async {
        // 1. 진행 중 메시지 표시
        await MainActor.run {
            manager.addChatLog(
                agentID: "system",
                agentName: "작업봇",
                text: "⏳ 작업 계획을 수립하는 중입니다...",
                isUser: false,
                roomID: roomID,
                isSystem: true
            )
        }

        // 2. LLM 플래너로 WorkflowPlan 생성
        guard let plan = await planWorkflow(userMessage: userMessage) else {
            AppLog.warning("[WorkflowOrchestrator] 플래닝 실패 → TeamOrchestrator 폴백")
            await TeamOrchestrator.shared.runTeamDiscussion(
                userMessage: userMessage,
                roomID: roomID,
                manager: manager
            )
            return
        }

        // 3. WorkflowEngine 실행
        let context = ToolExecutionContext.current()
        let result = await WorkflowEngine.shared.run(plan: plan, context: context)

        // 4. 결과 채팅방에 추가 (TTS 없음)
        await MainActor.run {
            manager.addChatLog(
                agentID: "system",
                agentName: "작업봇",
                text: result.summary,
                isUser: false,
                roomID: roomID,
                isSystem: false
            )
        }
    }

    // MARK: - LLM Planner

    private func planWorkflow(userMessage: String) async -> WorkflowPlan? {
        let toolSchemas = ToolRegistry.shared.toolSchemaDescription
        let plannerPrompt = """
        당신은 업무 워크플로우 계획자입니다.
        사용자 요청을 분석하고 아래 도구들을 사용하는 실행 계획을 JSON으로 반환하세요.
        JSON만 반환하고 다른 설명은 없어야 합니다.

        사용 가능한 도구:
        \(toolSchemas)

        출력 JSON 스키마 (모든 필드 필수):
        {
          "title": "워크플로우 제목",
          "steps": [
            {
              "id": "고유-UUID-문자열",
              "toolName": "도구이름",
              "title": "단계 제목",
              "input": {"param": "value"},
              "isRequired": true,
              "dependsOn": [],
              "riskLevel": "moderate"
            }
          ]
        }

        사용자 요청: \(userMessage)
        """

        do {
            let (jsonText, _) = try await AIService.shared.getResponse(
                text: plannerPrompt,
                agentID: "planner",
                chatHistory: []
            )
            let cleaned = extractJSON(from: jsonText)
            guard let data = cleaned.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(WorkflowPlan.self, from: data)
        } catch {
            AppLog.error("[WorkflowOrchestrator] planWorkflow 실패: \(error)")
            return nil
        }
    }

    private func extractJSON(from text: String) -> String {
        // ```json ... ``` 블록 추출
        if let startRange = text.range(of: "```json"),
           let endRange = text[startRange.upperBound...].range(of: "```") {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // ``` ... ``` 블록 (언어 없는 경우)
        if let startRange = text.range(of: "```"),
           let endRange = text[startRange.upperBound...].range(of: "```") {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // { ... } 최외곽 중괄호
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}
