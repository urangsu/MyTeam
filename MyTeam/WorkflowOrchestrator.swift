import Foundation

// MARK: - WorkflowOrchestrator
// TeamStatusView.sendTeamMessage()의 단일 진입점.
// IntentRouter를 1회만 호출하고 CHITCHAT → runChitchatOnly(), TASK → WorkflowEngine으로 라우팅.

final class WorkflowOrchestrator {
    static let shared = WorkflowOrchestrator()
    private init() {}

    // MARK: - Public entry point

    func dispatch(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async {
        // ── 파일/문서 생성 요청이면 IntentRouter 없이 즉시 Workflow로 ──
        // API 비용 절감: 명확한 파일 생성 요청은 분류 호출을 스킵한다.
        if requiresFileCreation(userMessage) {
            AppLog.info("[WorkflowOrchestrator] 파일 생성 요청 감지 → workflow 즉시 실행 (IntentRouter 스킵)")
            await runWorkflow(userMessage: userMessage, roomID: roomID, manager: manager)
            return
        }

        // ── 그 외: IntentRouter 1회 호출 ──
        let intent = await classifyIntent(message: userMessage, manager: manager)
        AppLog.info("[WorkflowOrchestrator] Intent: \(intent.rawValue)")

        switch intent {
        case .chitchat, .quickAnswer:
            // IntentRouter는 이미 1회 호출됨. TeamOrchestrator는 다시 분류하지 않는 전용 메서드 사용.
            await TeamOrchestrator.shared.runChitchatOnly(
                userMessage: userMessage,
                roomID: roomID,
                manager: manager
            )
        case .task, .research, .decision:
            await TeamOrchestrator.shared.runTeamDiscussion(
                userMessage: userMessage,
                roomID: roomID,
                manager: manager
            )
        }
    }

    // MARK: - File-creation heuristic

    /// 파일/문서 생성 의도가 담긴 메시지인지 판단한다.
    /// 산출물 명사 + 생성 동사가 함께 있을 때만 true.
    /// 동사("만들어", "정리") 단독으로는 false.
    ///
    /// TEST true:  "MyTeam 소개 보고서 만들어줘"
    /// TEST true:  "보고서 형태로 정리해줘"
    /// TEST true:  "기능 목록을 표로 정리해줘"
    /// TEST false: "이 아키텍처 문제점 정리해줘"
    /// TEST false: "이 사업 아이디어 초안 봐줘"
    private func requiresFileCreation(_ message: String) -> Bool {
        let lower = message.lowercased()

        // 산출물 명사 (파일/문서 결과물)
        let artifactNouns = ["보고서", "ppt", "프레젠테이션", "발표자료", "엑셀",
                             "스프레드시트", "파일", "문서", "초안"]
        // 생성 동사 — "정리" 포함 (artifact noun과 조합할 때만 true)
        let creationVerbs = ["만들어", "작성해", "생성해", "저장해", "정리"]

        let hasNoun = artifactNouns.contains { lower.contains($0) }
        let hasVerb = creationVerbs.contains { lower.contains($0) }

        // 산출물 명사 + 생성 동사 조합
        if hasNoun && hasVerb { return true }

        // "표로/표를" + 정리/만들/작성/생성 → 스프레드시트 생성 의도
        if (lower.contains("표로") || lower.contains("표를")) &&
            (lower.contains("정리") || lower.contains("만들") ||
             lower.contains("작성") || lower.contains("생성")) {
            return true
        }

        return false
    }

    // MARK: - Intent classification (1회)

    private func classifyIntent(message: String, manager: AgentWindowManager) async -> UserIntent {
        AppLog.info("[AICall] callType=intent_classify")
        do {
            let result = try await IntentRouter.shared.classify(
                message: message,
                activeAgents: manager.activeAgents
            )
            return result.intent
        } catch {
            AppLog.warning("[WorkflowOrchestrator] IntentRouter 실패, chitchat 폴백: \(error)")
            return .chitchat
        }
    }

    // MARK: - Workflow execution

    private func runWorkflow(userMessage: String, roomID: UUID, manager: AgentWindowManager) async {
        // 진행 중 알림
        await postChat(manager: manager, roomID: roomID, text: "⏳ 작업 계획을 수립하는 중입니다...", isSystem: true)

        // 15초 typing indicator 자동 해제 타이머
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    manager.typingAgentIDs.removeAll()
                }
            }
        }
        defer { timeoutTask.cancel() }

        // LLM 플래너 (self-repair 포함) — 실패 시 fallback 없이 에러 표시
        guard let plan = await planWorkflowWithRepair(userMessage: userMessage) else {
            await postChat(manager: manager, roomID: roomID,
                           text: "❌ 작업 계획 생성에 실패했습니다.\n요청을 더 구체적으로 작성해 주시거나, 잠시 후 다시 시도해 주세요.",
                           isSystem: false)
            return
        }

        let context = ToolExecutionContext.current()
        let result = await WorkflowEngine.shared.run(plan: plan, context: context)
        await postChat(manager: manager, roomID: roomID, text: result.summary, isSystem: false)
    }

    // MARK: - Planner with self-repair (최대 2회 시도)

    private func planWorkflowWithRepair(userMessage: String) async -> WorkflowPlan? {
        // 1차 시도
        let (plan1, error1) = await attemptPlan(userMessage: userMessage, previousError: nil)
        if let plan = plan1 { return plan }

        // 2차 시도 — 1차 오류를 프롬프트에 포함해 self-repair 요청
        let repairHint = error1 ?? "JSON 파싱에 실패했습니다."
        AppLog.info("[WorkflowOrchestrator] Self-repair 시도: \(repairHint)")
        let (plan2, _) = await attemptPlan(userMessage: userMessage, previousError: repairHint)
        return plan2
    }

    private func attemptPlan(
        userMessage: String,
        previousError: String?
    ) async -> (WorkflowPlan?, String?) {
        let callType = previousError == nil ? "workflow_plan" : "workflow_repair"
        AppLog.info("[AICall] callType=\(callType)")
        let prompt = buildPlannerPrompt(userMessage: userMessage, previousError: previousError)
        do {
            let (jsonText, _) = try await AIService.shared.getResponse(
                text: prompt,
                agentID: "planner",
                chatHistory: []
            )
            let cleaned = extractJSON(from: jsonText)
            guard let data = cleaned.data(using: .utf8) else {
                return (nil, "JSON 문자열을 Data로 변환하지 못했습니다.")
            }
            let plan = try JSONDecoder().decode(WorkflowPlan.self, from: data)
            return (plan, nil)
        } catch let decodeError as DecodingError {
            let msg = "JSON 디코딩 실패: \(decodeError.localizedDescription)"
            AppLog.error("[WorkflowOrchestrator] \(msg)")
            return (nil, msg)
        } catch {
            let errStr = error.localizedDescription
            // 429 → 사용자 친화적 메시지
            if errStr.contains("429") || errStr.contains("사용량 제한") || errStr.contains("Rate limit") {
                let msg = "⚠️ API 사용량 제한에 걸렸습니다. 잠시 후 다시 시도해 주세요."
                AppLog.warning("[WorkflowOrchestrator] 429 감지: \(errStr)")
                return (nil, msg)
            }
            let msg = "LLM 호출 실패: \(errStr)"
            AppLog.error("[WorkflowOrchestrator] \(msg)")
            return (nil, msg)
        }
    }

    // MARK: - Planner prompt builder

    private func buildPlannerPrompt(userMessage: String, previousError: String?) -> String {
        let toolSchemas = ToolRegistry.shared.toolSchemaDescription
        var prompt = """
        당신은 업무 워크플로우 계획자입니다.
        사용자 요청을 분석하고 아래 도구들을 사용하는 실행 계획을 JSON으로 반환하세요.
        JSON 블록(```json ... ```)만 반환하고 다른 설명은 없어야 합니다.

        사용 가능한 도구:
        \(toolSchemas)

        출력 JSON 스키마:
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

        [필수 2단계 규칙 — 반드시 지켜라]
        - PPT/프레젠테이션 요청: 1단계 create_presentation_plan → 2단계 generate_pptx
        - 엑셀/스프레드시트/표 요청: 1단계 create_spreadsheet_plan → 2단계 generate_xlsx
        - 1단계의 output filename(filename 파라미터)과 2단계의 plan_filename이 반드시 같아야 한다.
        - Google 슬라이드 요청: 1단계 create_presentation_plan → 2단계 create_google_slides
        - Google 시트 요청: 1단계 create_spreadsheet_plan → 2단계 create_google_sheets
        - output_filename은 한글 포함 가능. 확장자 포함 (예: MyTeam_소개.pptx, 기능표.xlsx).

        사용자 요청: \(userMessage)
        """

        if let err = previousError {
            prompt += "\n\n[이전 시도 오류 — 수정 후 재생성]\n\(err)"
        }
        return prompt
    }

    // MARK: - JSON extraction

    private func extractJSON(from text: String) -> String {
        // ```json ... ``` 블록
        if let s = text.range(of: "```json"),
           let e = text[s.upperBound...].range(of: "```") {
            return String(text[s.upperBound..<e.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // ``` ... ``` 블록 (언어 없음)
        if let s = text.range(of: "```"),
           let e = text[s.upperBound...].range(of: "```") {
            return String(text[s.upperBound..<e.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 최외곽 { ... }
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
            return String(text[s...e])
        }
        return text
    }

    // MARK: - Chat helper

    @MainActor
    private func postChat(
        manager: AgentWindowManager,
        roomID: UUID,
        text: String,
        isSystem: Bool
    ) {
        manager.addChatLog(
            agentID: "system",
            agentName: "작업봇",
            text: text,
            isUser: false,
            roomID: roomID,
            isSystem: isSystem
        )
    }
}
