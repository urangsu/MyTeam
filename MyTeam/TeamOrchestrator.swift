import Foundation

// MARK: - TeamOrchestrator
// AutoGen SelectorGroupChat + CrewAI Memory 하이브리드
// 팀 대화에서 LLM이 다음 화자를 선택하며 에이전트 간 유기적 토의를 이끈다.

class TeamOrchestrator {
    static let shared = TeamOrchestrator()

    private let memory = ConversationMemory()
    private var lastDiscussionTime: Date = .distantPast
    private let discussionCooldown: TimeInterval = 2.0  // 최소 2초 간격
    
    // MARK: - 시스템 맥락 정보 (시공간 정보 주입)
    
    private func getSystemContextPrompt() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 EEEE HH:mm"
        let dateString = formatter.string(from: now)
        
        let month = Calendar.current.component(.month, from: now)
        let season: String
        switch month {
        case 3...5: season = "봄"
        case 6...8: season = "여름"
        case 9...11: season = "가을"
        default: season = "겨울"
        }
        
        let location = AgentWindowManager.shared.userLocation
        
        return """
        [현재 시스템 및 환경 정보]
        - 현재 시간: \(dateString)
        - 현재 계절: \(season)
        - 사용자 위치: \(location)
        (위 정보를 바탕으로 지금 시기와 장소에 맞는 현실적인 응답을 하세요. 계절에 어긋나는 활동이나 대화는 절대 하지 마세요.)
        """
    }

    // MARK: - 팀 토의 실행

    /// 사용자 메시지를 받아 팀 토의 혹은 작업을 자동으로 진행한다.
    func runTeamDiscussion(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager,
        maxTurns: Int = 6
    ) async {
        // 디바운싱: 마지막 토의로부터 2초 이상 경과해야만 진행
        let now = Date()
        guard now.timeIntervalSince(lastDiscussionTime) >= discussionCooldown else { return }
        lastDiscussionTime = now

        let agents = manager.activeAgents
        guard !agents.isEmpty else { return }

        // 이전 토의의 대기 음성 즉시 중단
        SpeechManager.shared.stopSpeaking()

        do {
            // 1. 의도 분류 및 리더 추천 (Intent Router)
            let routing = try await IntentRouter.shared.classify(message: userMessage, activeAgents: agents)
            
            if routing.intent == .task {
                // [TRACK A] 업무 모드 (Task Mode)
                await runTaskMode(routing: routing, userMessage: userMessage, roomID: roomID, manager: manager)
            } else {
                // [TRACK B] 수다 모드 (Chitchat Mode) - 기존 릴레이 방식
                await runChitchatMode(userMessage: userMessage, roomID: roomID, manager: manager, maxTurns: 3)
            }
            
            // 3. 대화 완료 후 핵심 정보는 manager.keyFacts로 관리 (extractKeyFacts 제거)
            // 필요 시 별도 요약 로직으로 대체 가능
            
        } catch {
            print("Orchestration Error: \(error)")
            await MainActor.run {
                manager.addChatLog(agentID: "system", agentName: "시스템", text: "팀 업무 수행 중 오류가 발생했습니다: \(error.localizedDescription)", isUser: false, roomID: roomID)
            }
        }
    }

    // MARK: - [TRACK A] 업무 모드 (Task Mode)
    
    private func runTaskMode(
        routing: IntentResult,
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async {
        guard let orders = routing.workOrders, !orders.isEmpty else { return }
        let agents = manager.activeAgents
        
        // 1. 첫 수행자의 주도적 제안 (Routing에 명시된 경우)
        if let firstOrderID = orders.first?.agentID,
           let firstAgent = agents.first(where: { $0.id == firstOrderID }),
           let proposal = routing.proactiveMessage {
            await MainActor.run {
                manager.addChatLog(agentID: firstAgent.id, agentName: firstAgent.name, text: proposal, isUser: false, roomID: roomID)
                if !manager.isSilentMode {
                    manager.setAgentSpeaking(agentID: firstAgent.id, text: proposal)
                    SpeechManager.shared.speak(text: proposal, agentID: firstAgent.id, characterName: firstAgent.name)
                }
            }
            // 첫 에이전트의 발성이 완료될 때까지 대기
            var waitCount = 0
            while manager.speakingAgentID == firstAgent.id && waitCount < 120 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waitCount += 1
            }
            try? await Task.sleep(nanoseconds: 600_000_000)  // 간격
        }
        
        // 2. 지시서(Work Orders) 순차 수행
        for (index, order) in orders.enumerated() {
            guard let agent = agents.first(where: { $0.id == order.agentID }) else { continue }

            let history = manager.rooms.first(where: { $0.id == roomID })?.messages.suffix(10) ?? []
            let historyText = history.map { "[\($0.agentName)] \($0.text)" }.joined(separator: "\n")

            let taskPrompt = """
            당신은 시스템 팀장으로부터 특정 업무를 하달받은 전문가 '\(agent.name)'입니다.
            분야: \(routing.taskCategory ?? "일반") / 성격: \(agent.role)

            \(getSystemContextPrompt())

            [시스템 팀장의 지시서]
            귀하의 이번 역할은 다음과 같습니다: "\(order.subTask)"

            [이전 대화 맥락]
            \(historyText)

            [지시]
            시스템의 지시서에 따라 귀하의 전문성을 발휘하여 답변하세요.
            절대 본인이 팀장인 것처럼 행동하지 말고, 배정받은 '전문가'로서의 역할에 충실하세요.
            답변은 3~5문장 이내로 핵심만 명확하게 전달하세요.

            [업무 규칙]
            1. 절대 약하거나 모호한 결과를 통과시키지 마세요 (Don't pass through weak results).
            2. 연극 대본을 쓰지 말고, 오직 당신의 답변 본문만 출력하세요.
            3. 답변 시작 시 당신의 이름(예: [\(agent.name)], \(agent.name):)을 절대로 붙이지 마세요.
            """

            do {
                let (responseText, _) = try await AIService.shared.getResponse(
                    text: "\(taskPrompt)\n\n[사용자 지시]: \(userMessage)",
                    agentID: agent.id,
                    chatHistory: [],
                    agentConfig: agent
                )

                await MainActor.run {
                    manager.addChatLog(agentID: agent.id, agentName: agent.name, text: responseText, isUser: false, roomID: roomID)
                    if !manager.isSilentMode {
                        manager.setAgentSpeaking(agentID: agent.id, text: responseText)
                        SpeechManager.shared.speak(text: responseText, agentID: agent.id, characterName: agent.name)
                    }
                }

                // 현재 에이전트의 발성이 완료될 때까지 대기
                var waitCount = 0
                while manager.speakingAgentID == agent.id && waitCount < 120 {  // 최대 120초 대기
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1초씩 확인
                    waitCount += 1
                }

                // 에이전트 간 자연스러운 간격
                if index < orders.count - 1 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }

            } catch {
                print("Work Order Execution Error (\(agent.name)): \(error)")
            }
        }
        
        // 3. 서포터의 짧은 리액션 (나머지 에이전트 중 1명)
        let workerIDs = Set(orders.map { $0.agentID })
        let availableSupporters = agents.filter { !workerIDs.contains($0.id) }
        if let supporter = availableSupporters.randomElement() {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let interjectionPrompt = "동료들의 전문적인 작업 결과에 대해 본인의 페르소나(\(supporter.role))에 맞게 아주 짧은 리액션이나 격려를 1문장만 하세요."
            if let (interText, _) = try? await AIService.shared.getResponse(
                text: "\(interjectionPrompt)\n\n동료들의 작업 완료",
                agentID: supporter.id,
                chatHistory: [],
                agentConfig: supporter
            ) {
                await MainActor.run {
                    manager.addChatLog(agentID: supporter.id, agentName: supporter.name, text: interText, isUser: false, roomID: roomID)
                    if !manager.isSilentMode {
                        manager.setAgentSpeaking(agentID: supporter.id, text: interText)
                        SpeechManager.shared.speak(text: interText, agentID: supporter.id, characterName: supporter.name)
                    }
                }
                // 서포터의 발성이 완료될 때까지 대기
                var waitCount = 0
                while manager.speakingAgentID == supporter.id && waitCount < 120 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    waitCount += 1
                }
            }
        }
    }

    // MARK: - [TRACK B] 수다 모드 (Chitchat Mode)

    private func runChitchatMode(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager,
        maxTurns: Int
    ) async {
        var lastSpeakerID: String? = nil
        let agents = manager.activeAgents

        for turn in 0..<maxTurns {
            let history = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
            guard let nextAgentID = await selectNextSpeaker(history: history, agents: agents, lastSpeakerID: lastSpeakerID, userMessage: userMessage) else { break }
            guard let agent = agents.first(where: { $0.id == nextAgentID }) else { break }

            let prompt = buildDiscussionPrompt(agent: agent, history: history, turn: turn, totalAgents: agents.count)

            do {
                let (responseText, _) = try await AIService.shared.getResponse(text: prompt, agentID: agent.id, chatHistory: Array(history.suffix(3)), agentConfig: agent)
                await MainActor.run {
                    manager.addChatLog(agentID: agent.id, agentName: agent.name, text: responseText, isUser: false, roomID: roomID)
                    if !manager.isSilentMode {
                        manager.setAgentSpeaking(agentID: agent.id, text: responseText)
                        SpeechManager.shared.speak(text: responseText, agentID: agent.id, characterName: agent.name)
                    }
                }
                lastSpeakerID = agent.id

                // 현재 에이전트의 발성이 완료될 때까지 대기
                var waitCount = 0
                while manager.speakingAgentID == agent.id && waitCount < 120 {  // 최대 120초 대기
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1초씩 확인
                    waitCount += 1
                }

                // 다음 에이전트까지의 자연스러운 간격
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.5...1.0) * 1_000_000_000))
            } catch { break }
        }
    }

    // MARK: - LLM Selector (AutoGen 패턴)

    /// 대화 맥락을 분석하여 다음에 발언할 에이전트를 선택한다.
    /// nil 반환 = 대화 자연 종료 ("DONE")
    private func selectNextSpeaker(
        history: [AgentWindowManager.ChatLog],
        agents: [AgentWindowManager.AgentConfig],
        lastSpeakerID: String?,
        userMessage: String
    ) async -> String? {
        let agentDescriptions = agents.map { agent -> String in
            let persona = agentPersonas[agent.id]
            return "- \(agent.name)(\(agent.id)): \(persona?.role ?? agent.role)"
        }.joined(separator: "\n")

        // 최근 대화 요약 (Selector용 — 짧게)
        let recentMessages = history.suffix(8).map { log -> String in
            if log.isUser { return "사용자: \(log.text)" }
            return "\(log.agentName): \(log.text.prefix(100))"
        }.joined(separator: "\n")

        let lastSpeakerName = agents.first(where: { $0.id == lastSpeakerID })?.name ?? "없음"

        let selectorPrompt = """
        당신은 팀 대화의 진행자입니다. 아래 대화를 읽고, 다음에 발언해야 할 에이전트의 ID를 선택하세요.

        [참가자]
        \(agentDescriptions)

        [사용자의 원래 질문]
        \(userMessage)

        [최근 대화]
        \(recentMessages)

        [직전 화자]
        \(lastSpeakerName)

        [규칙]
        1. 직전 화자는 연속 선택 불가
        2. 주제와 관련 있는 전문가를 우선 선택
        3. 이미 충분히 의견이 나왔고 새로운 관점이 없으면 "DONE" 출력
        4. 반론이나 보충이 필요하면 해당 전문 에이전트 선택
        5. 답변은 에이전트 ID만 출력 (예: "agent_6") 또는 "DONE"
        """

        do {
            // Selector는 경량 호출 — 짧은 응답만 필요
            let selectorAgent = agents.first(where: { $0.id == "agent_1" }) ?? agents.first
            let (result, _) = try await AIService.shared.getResponse(
                text: selectorPrompt, agentID: selectorAgent?.id ?? "agent_1", chatHistory: [], agentConfig: selectorAgent
            )

            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if trimmed.contains("done") { return nil }

            // agent_N 형식 추출
            if let match = trimmed.range(of: #"agent_\d+"#, options: .regularExpression) {
                let agentID = String(trimmed[match])
                // 직전 화자 연속 방지
                if agentID == lastSpeakerID {
                    let others = agents.filter { $0.id != lastSpeakerID }
                    return others.randomElement()?.id
                }
                return agentID
            }

            // 이름으로 매칭 시도
            for agent in agents where agent.id != lastSpeakerID {
                if trimmed.contains(agent.name.lowercased()) {
                    return agent.id
                }
            }

            // 매칭 실패 시 직전 화자 제외 랜덤
            return agents.filter { $0.id != lastSpeakerID }.randomElement()?.id

        } catch {
            // Selector 실패 시 직전 화자 제외 랜덤
            return agents.filter { $0.id != lastSpeakerID }.randomElement()?.id
        }
    }

    // MARK: - 토의용 프롬프트 생성

    /// 팀 토의에서 에이전트가 서로의 발언을 참조해 응답하도록 프롬프트를 구성한다.
    private func buildDiscussionPrompt(
        agent: AgentWindowManager.AgentConfig,
        history: [AgentWindowManager.ChatLog],
        turn: Int,
        totalAgents: Int
    ) -> String {
        // 과거 페르소나 오염 방지를 위한 엄격한 슬라이딩 윈도우 (최신 3개만)
        let otherAgentMessages = history.suffix(3)
            .filter { !$0.isUser && !$0.isSystem && $0.agentID != agent.id }
            .map { "[\($0.agentName)] \($0.text)" }
            .joined(separator: "\n")

        let role: String
        if turn == 0 {
            role = "이 주제에 대해 첫 의견을 제시하는 역할"
        } else if turn >= 4 {
            role = "지금까지 논의를 정리하고 결론을 도출하는 역할"
        } else {
            // 역할 다양화: 동의, 반론, 보충 중 하나
            let roles = [
                "이전 동료의 의견에 동의하거나 반론을 제기하는 역할",
                "이전 논의에서 빠진 관점을 보충하는 역할",
                "자신의 전문 분야에서 구체적 의견을 추가하는 역할"
            ]
            role = roles[turn % roles.count]
        }

        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "한국어"

        var prompt = ""
        prompt += "당신은 현재 단체 채팅방에 참여 중인 '\(agent.name)' 본인입니다. 연극 대본 작가가 아님을 명심하세요.\n\n"
        prompt += getSystemContextPrompt() + "\n\n"

        if !otherAgentMessages.isEmpty {
            prompt += "[이전 채팅 내용]\n\(otherAgentMessages)\n\n"
        }
        prompt += "[당신의 역할] \(role)\n\n"
        prompt += "[최우선 채팅 규칙]\n"
        prompt += "0. 모든 대답은 반드시 '\(appLanguage)'로만 작성하세요.\n"
        prompt += "1. 당신은 오직 당신('\(agent.name)')의 대답만 출력해야 합니다. 절대 다른 사람의 대사를 대신 작성하거나 '<user>' 같은 시스템 태그를 멋대로 생성하지 마세요.\n"
        prompt += "2. 한 번에 너무 많은 말을 늘어놓지 마세요. 실제 카카오톡이나 메신저처럼 핵심만 1~3문장 이내로 아주 짧게 대답하세요.\n"
        prompt += "3. 마음속 생각이나 상황 설명(\"아직 내 얘기 못했는데...\", \"흠...\")은 절대 출력하지 말고 바로 채팅방에 입력할 텍스트만 출력하세요.\n"
        prompt += "4. 답변 말머리(문장 시작)에 당신의 이름(예: [\(agent.name)], \(agent.name):)을 절대로 붙이지 마세요.\n"

        return prompt
    }
}
