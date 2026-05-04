import Foundation

// MARK: - WorkflowOrchestrator
// TeamStatusView.sendTeamMessage()의 단일 진입점.
// IntentRouter를 1회만 호출하고 CHITCHAT → runChitchatOnly(), TASK → WorkflowEngine으로 라우팅.

final class WorkflowOrchestrator {
    static let shared = WorkflowOrchestrator()
    private init() {}

    // MARK: - 취소 지원
    private var currentWorkflowTask: Task<Void, Never>?

    /// 현재 실행 중인 workflow를 즉시 취소한다.
    func cancelCurrentWorkflow(roomID: UUID, manager: AgentWindowManager) {
        guard let task = currentWorkflowTask, !task.isCancelled else { return }
        task.cancel()
        currentWorkflowTask = nil
        Task { @MainActor in
            manager.typingAgentIDs.removeAll()
            manager.isWorkflowRunning = false
            manager.addChatLog(
                roomID: roomID, agentID: "system", agentName: "작업봇",
                text: "🛑 작업을 중지했습니다.", isUser: false, isSystem: true
            )
        }
        AppLog.info("[WorkflowOrchestrator] 워크플로우 취소됨")
    }

    // isWorkflowRunning은 AgentWindowManager.isWorkflowRunning(@Published)으로 관리

    // MARK: - Public entry point

    func dispatch(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async {
        // ── 이전 workflow가 남아 있으면 조용히 취소 ──
        currentWorkflowTask?.cancel()
        currentWorkflowTask = nil

        // ── 새 요청 → 세션 예산 리셋 ──
        AICallBudgetManager.shared.beginSession()

        // ── 이벤트: userMessageSubmitted ──
        let eventRoomID = roomID
        let eventMsg = userMessage
        Task { await AgentEventBus.shared.publish(.userMessageSubmitted(roomID: eventRoomID, message: eventMsg)) }

        // ── 파일/문서 생성 요청이면 IntentRouter 없이 즉시 Workflow로 ──
        if requiresFileCreation(userMessage) {
            AppLog.info("[WorkflowOrchestrator] 파일 생성 요청 감지 → workflow 즉시 실행 (IntentRouter 스킵)")
            Task { await AgentEventBus.shared.publish(AgentEvent(type: .routeDecided, roomID: eventRoomID,
                                                                  payload: AgentEventPayload(message: "artifactGeneration"))) }
            await MainActor.run { manager.isWorkflowRunning = true }
            // defer: cancel/failure/success/early return 모든 경로에서 false 보장
            defer { Task { @MainActor in manager.isWorkflowRunning = false } }
            let task = Task { await self.runWorkflow(userMessage: userMessage, roomID: roomID, manager: manager) }
            currentWorkflowTask = task
            await task.value
            currentWorkflowTask = nil
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
        guard AICallBudgetManager.shared.requestCall(.intentClassify) else {
            AppLog.warning("[Budget] intent_classify 차단")
            return .chitchat
        }
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

    // MARK: - PlannerResult — 실패 이유를 사용자까지 보존

    private enum PlannerResult {
        case success(WorkflowPlan)
        case failure(String)   // 사용자에게 그대로 표시할 메시지

        var plan: WorkflowPlan? {
            if case .success(let p) = self { return p }
            return nil
        }
        var failureMessage: String? {
            if case .failure(let m) = self { return m }
            return nil
        }
    }

    // MARK: - Workflow execution

    private func runWorkflow(userMessage: String, roomID: UUID, manager: AgentWindowManager) async {
        guard !Task.isCancelled else { return }

        // ── workflowID 생성 (이번 workflow의 추적 키) ──
        let workflowID = UUID()
        await MainActor.run {
            manager.currentWorkflowID = workflowID
            WorkflowRunStore.shared.begin(workflowID: workflowID, roomID: roomID, userMessage: userMessage)
        }
        defer {
            Task { @MainActor in manager.currentWorkflowID = nil }
        }

        Task { await AgentEventBus.shared.publish(.workflowStarted(workflowID: workflowID, roomID: roomID)) }

        // ephemeral 진행 메시지 — 완료/실패 시 제거됨
        let progressMsgID = postEphemeralProgress(
            manager: manager, roomID: roomID, text: "⏳ 작업 계획을 수립하는 중입니다..."
        )

        // 15초 typing indicator 자동 해제 타이머
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { manager.typingAgentIDs.removeAll() }
            }
        }
        defer { timeoutTask.cancel() }

        guard !Task.isCancelled else {
            await MainActor.run { WorkflowRunStore.shared.finish(workflowID: workflowID, status: .cancelled) }
            Task { await AgentEventBus.shared.publish(.workflowCancelled(workflowID: workflowID, roomID: roomID)) }
            return
        }

        switch await planWorkflowWithRepair(userMessage: userMessage) {
        case .failure(let msg):
            guard !Task.isCancelled else { return }
            await MainActor.run {
                WorkflowRunStore.shared.finish(workflowID: workflowID, status: .failed)
                removeProgressAndPost(manager: manager, roomID: roomID, progressID: progressMsgID, text: msg, isSystem: false)
            }
            Task { await AgentEventBus.shared.publish(.modelCallFailed(workflowID: workflowID, provider: "planner", error: msg)) }
        case .success(let plan):
            guard !Task.isCancelled else { return }
            let context = ToolExecutionContext.current(workflowID: workflowID, roomID: roomID)
            let result = await WorkflowEngine.shared.run(plan: plan, context: context)
            guard !Task.isCancelled else { return }
            let status: WorkflowStatus = result.failedSteps.isEmpty ? .completed : .failed
            let artifactCount = result.artifacts.count
            await MainActor.run {
                WorkflowRunStore.shared.finish(workflowID: workflowID, status: status)
                removeProgressAndPost(manager: manager, roomID: roomID, progressID: progressMsgID, text: result.summary, isSystem: false)
            }
            Task { await AgentEventBus.shared.publish(.workflowCompleted(workflowID: workflowID, roomID: roomID, artifactCount: artifactCount)) }
        }
    }

    // MARK: - Ephemeral progress 메시지 헬퍼

    @MainActor
    private func postEphemeralProgress(manager: AgentWindowManager, roomID: UUID, text: String) -> UUID {
        let msgID = UUID()
        guard let idx = manager.rooms.firstIndex(where: { $0.id == roomID }) else { return msgID }
        let log = AgentWindowManager.ChatLog(
            id: msgID, agentID: "system", agentName: "작업봇",
            text: text, isUser: false, timestamp: Date(), isSystem: true, sources: []
        )
        manager.rooms[idx].messages.append(log)
        return msgID
    }

    @MainActor
    private func removeProgressAndPost(
        manager: AgentWindowManager, roomID: UUID, progressID: UUID, text: String, isSystem: Bool
    ) {
        // TODO: P1 — ChatLog 삽입 방식 대신 manager.workflowStatusText(@Published)로 분리
        //       rooms 저장과 결합도가 높아 데모 이후 별도 UI state로 교체할 것.
        guard let idx = manager.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        // ephemeral 메시지 제거
        manager.rooms[idx].messages.removeAll { $0.id == progressID }
        // 실제 결과 추가
        let log = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "system", agentName: "작업봇",
            text: text, isUser: false, timestamp: Date(), isSystem: isSystem, sources: []
        )
        manager.rooms[idx].messages.append(log)
    }

    // MARK: - Planner with self-repair (최대 2회 시도)

    private func planWorkflowWithRepair(userMessage: String) async -> PlannerResult {
        // 1차 시도
        let result1 = await attemptPlan(userMessage: userMessage, previousError: nil)
        if case .success = result1 { return result1 }
        guard case .failure(let error1) = result1 else { return result1 }

        // 429나 provider 오류는 재시도해도 소용없음 — 즉시 반환
        if error1.contains("사용량 제한") || error1.contains("429") {
            return result1
        }

        // 2차 시도 — JSON/decode 오류에 대해서만 self-repair
        AppLog.info("[WorkflowOrchestrator] Self-repair 시도: \(error1)")
        return await attemptPlan(userMessage: userMessage, previousError: error1)
    }

    private func attemptPlan(
        userMessage: String,
        previousError: String?
    ) async -> PlannerResult {
        let callType = previousError == nil ? "workflow_plan" : "workflow_repair"
        let budgetType: AICallType = previousError == nil ? .workflowPlan : .workflowRepair
        guard AICallBudgetManager.shared.requestCall(budgetType) else {
            let msg = AICallBudgetManager.shared.blockedMessage(for: budgetType)
            AppLog.warning("[Budget] \(callType) 차단")
            return .failure(msg)
        }
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
                return .failure("❌ 작업 계획 생성에 실패했습니다 (JSON 변환 오류).\n다시 시도해 주세요.")
            }
            let plan = try JSONDecoder().decode(WorkflowPlan.self, from: data)
            return .success(plan)
        } catch let decodeError as DecodingError {
            let msg = "❌ 작업 계획 생성에 실패했습니다 (JSON 형식 오류).\n요청을 더 구체적으로 작성해 주세요."
            AppLog.error("[WorkflowOrchestrator] JSON decode: \(decodeError.localizedDescription)")
            return .failure(msg)
        } catch {
            let errStr = error.localizedDescription
            if errStr.contains("429") || errStr.contains("사용량 제한") || errStr.contains("Rate limit") {
                let msg = "⚠️ API 사용량 제한에 걸렸습니다. 잠시 후 다시 시도해 주세요."
                AppLog.warning("[WorkflowOrchestrator] 429 감지: \(errStr)")
                return .failure(msg)
            }
            let msg = "❌ 작업 계획 생성에 실패했습니다.\n요청을 다시 작성하거나 잠시 후 시도해 주세요."
            AppLog.error("[WorkflowOrchestrator] LLM 호출 실패: \(errStr)")
            return .failure(msg)
        }
    }

    // MARK: - Planner prompt builder

    private func buildPlannerPrompt(userMessage: String, previousError: String?) -> String {
        // 파일 생성 요청: artifactGeneration scope만 노출 (chatBasic 포함)
        // browserDOM / officeLive / diagnostics는 명시적 활성화 없이 노출 금지
        let activeScopes: Set<ToolScope> = [.chatBasic, .artifactGeneration]
        let toolSchemas = ToolRegistry.shared.toolSchemaDescription(for: activeScopes)
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
            roomID: roomID,
            agentID: "system",
            agentName: "작업봇",
            text: text,
            isUser: false,
            isSystem: isSystem
        )
    }
}
