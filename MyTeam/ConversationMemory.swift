import Foundation
import AppKit
import PDFKit

// MARK: - ConversationMemory
// CrewAI Scoped Memory 패턴 — 팀/에이전트별 대화 기억 관리

class ConversationMemory {

    // MARK: - 대화 요약 (토큰 관리)

    /// 30개 초과 메시지를 AI로 요약하여 컨텍스트 윈도우 관리
    static func compactHistory(
        messages: [AgentWindowManager.ChatLog],
        maxMessages: Int = 30
    ) async -> [AgentWindowManager.ChatLog] {
        guard messages.count > maxMessages else { return messages }

        // 오래된 메시지를 요약으로 압축, 최근 메시지는 유지
        let oldMessages = Array(messages.prefix(messages.count - maxMessages))
        let recentMessages = Array(messages.suffix(maxMessages))

        // 요약 생성
        let summaryText = buildSummaryText(from: oldMessages)

        let summaryLog = AgentWindowManager.ChatLog(
            id: UUID(),
            agentID: "system",
            agentName: "시스템",
            text: "[이전 대화 요약] \(summaryText)",
            isUser: false,
            timestamp: oldMessages.last?.timestamp ?? Date(),
            isSystem: false,
            sources: []
        )

        return [summaryLog] + recentMessages
    }

    /// 메시지 목록을 간단한 요약 텍스트로 변환
    private static func buildSummaryText(from messages: [AgentWindowManager.ChatLog]) -> String {
        // 참가자 목록
        let participants = Set(messages.filter { !$0.isUser && !$0.isSystem }.map { $0.agentName })
        let participantList = participants.joined(separator: ", ")

        // 주요 발언 추출 (각 참가자의 마지막 발언)
        var lastMessages: [String: String] = [:]
        for msg in messages where !msg.isUser && !msg.isSystem {
            lastMessages[msg.agentName] = String(msg.text.prefix(80))
        }

        // 사용자 주요 질문
        let userQuestions = messages.filter { $0.isUser }.map { String($0.text.prefix(60)) }
        let questionSummary = userQuestions.isEmpty ? "" : "사용자 질문: \(userQuestions.suffix(3).joined(separator: " / "))"

        var summary = "참가자: \(participantList). "
        summary += questionSummary
        for (name, text) in lastMessages {
            summary += " \(name): \(text)."
        }

        return String(summary.prefix(500))
    }

    // MARK: - 첨부파일 컨텍스트 생성

    /// 첨부파일 정보를 AI 프롬프트에 주입할 텍스트로 변환
    static func buildAttachmentContext(from attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else { return "" }

        var context = "\n[첨부 자료]\n"
        for attachment in attachments {
            switch attachment.type {
            case .text:
                context += "- 텍스트 파일 '\(attachment.fileName)': \(String(attachment.textContent?.prefix(2000) ?? ""))\n"
            case .image:
                context += "- 이미지 '\(attachment.fileName)' (첨부됨)\n"
            case .pdf:
                context += "- PDF '\(attachment.fileName)': \(String(attachment.textContent?.prefix(2000) ?? ""))\n"
            case .document:
                context += "- 문서 '\(attachment.fileName)': \(String(attachment.textContent?.prefix(2000) ?? ""))\n"
            case .other:
                context += "- 파일 '\(attachment.fileName)' (\(attachment.fileSize) bytes)\n"
            }
        }
        return context
    }

    // MARK: - 채팅 명령어

    @MainActor
    static func handleChatCommand(
        _ rawText: String,
        roomID: UUID?,
        manager: AgentWindowManager,
        currentAgent: AgentWindowManager.AgentConfig? = nil
    ) async -> Bool {
        let commandText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard commandText.hasPrefix("/") else { return false }

        let parts = commandText.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let command = parts.first.map { String($0).lowercased() } ?? ""
        let argument = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let agentName = currentAgent?.name ?? "시스템"

        func post(_ text: String, sources: [AgentWindowManager.SourceReference] = []) {
            guard let rid = roomID else { return }
            manager.addChatLog(
                roomID: rid,
                agentID: "system",
                agentName: "시스템",
                text: text,
                isUser: false,
                sources: sources
            )
        }

        switch command {
        case "/help", "/?":
            post("""
            사용 가능한 명령어
            /clear - 현재 방 대화 지우기
            /compact - 현재 방 대화 요약 압축
            /remember 내용 - 장기 기억에 저장
            /memory - 저장된 장기 기억 보기
            /forget 내용 - 일치하는 기억 삭제
            /forget all - 모든 장기 기억 삭제
            /open URL 또는 파일경로 - 브라우저/파일 열기
            /fetch URL - 웹페이지 직접 읽기
            /search 검색어 - 웹 자료 찾기
            /schedule 09:00 할 일 - 앱이 켜져 있을 때 예약 실행
            /schedule every 30m 할 일 - 반복 예약
            /tasks - 스케줄 업무 보기
            /cancel 번호 - 스케줄 업무 삭제
            /silent on|off - 무음 모드 전환
            /voice on|off - 음성 모드 전환
            """)
            return true

        case "/clear":
            guard let roomID else {
                post("현재 방을 찾지 못했습니다.")
                return true
            }
            manager.clearMessages(roomID: roomID)
            manager.addChatLog(
                roomID: roomID,  // non-optional here (guard let roomID above)
                agentID: "system",
                agentName: "시스템",
                text: "현재 방 대화를 지웠습니다.",
                isUser: false
            )
            return true

        case "/compact":
            guard let roomID,
                  let room = manager.rooms.first(where: { $0.id == roomID }) else {
                post("현재 방을 찾지 못했습니다.")
                return true
            }
            let visibleMessages = room.messages.filter { !$0.isSystem }
            guard visibleMessages.count > 4 else {
                post("압축할 만큼 대화가 많지 않습니다.")
                return true
            }
            post("대화를 요약 중입니다...")
            // LLM 기반 요약 시도, 실패 시 정적 요약 fallback
            let dialogText = visibleMessages.suffix(40)
                .map { "\($0.isUser ? "사용자" : $0.agentName): \(String($0.text.prefix(200)))" }
                .joined(separator: "\n")
            let llmPrompt = """
            다음 AI 팀 대화를 3~5문장으로 압축 요약해줘. \
            핵심 결정사항, 중요 정보, 미완료 작업 위주로. 한국어로 답해.
            \(dialogText)
            """
            let llmSummary = await AIService.shared.quickSummary(prompt: llmPrompt)
            let useLLM = !llmSummary.hasPrefix("(요약 실패")
            let compacted: [AgentWindowManager.ChatLog]
            if useLLM {
                // LLM 요약본 1개 + 최근 8개 메시지 유지
                let summaryLog = AgentWindowManager.ChatLog(
                    id: UUID(), agentID: "system", agentName: "시스템",
                    text: "[AI 요약] \(llmSummary)",
                    isUser: false, timestamp: visibleMessages.last?.timestamp ?? Date(),
                    isSystem: false, sources: []
                )
                compacted = [summaryLog] + Array(visibleMessages.suffix(8))
            } else {
                compacted = await compactHistory(messages: visibleMessages, maxMessages: 8)
            }
            manager.replaceMessages(roomID: roomID, with: compacted)
            manager.addChatLog(
                roomID: roomID,
                agentID: "system", agentName: "시스템",
                text: useLLM ? "AI가 이전 대화를 요약했습니다." : "이전 대화를 요약하고 최근 흐름만 남겼습니다.",
                isUser: false
            )
            return true

        case "/remember":
            guard !argument.isEmpty else {
                post("""
                저장할 내용을 같이 입력해 주세요.
                • /remember 내용 → 이 방 기억
                • /remember @루나 내용 → 루나 전용 기억
                • /remember :global 내용 → 수석님 전체 기억
                """)
                return true
            }
            // Scope prefix 파싱
            let (scope, content) = parseMemoryScope(argument, roomID: roomID)
            if content.isEmpty {
                post("저장할 내용이 비어 있습니다.")
                return true
            }
            if manager.addScopedFact(content, scope: scope) {
                post("[\(scope.label)] 장기 기억에 저장했습니다: \(content)")
            } else {
                post("이 내용은 민감할 수 있어 장기 기억에 저장하지 않았습니다.\n필요하면 별도 승인 후 저장하도록 바꿀 수 있습니다.")
            }
            return true

        case "/memory":
            let allFacts = manager.allScopedFacts(agentName: agentName, roomID: roomID)
            if allFacts.isEmpty {
                post("저장된 장기 기억이 없습니다.")
            } else {
                let lines = allFacts.flatMap { (label, facts) in
                    ["\(label):"] + facts.enumerated().map { "  \($0.offset + 1). \($0.element)" }
                }.joined(separator: "\n")
                post("저장된 장기 기억\n\(lines)")
            }
            return true

        case "/forget":
            guard !argument.isEmpty else {
                post("삭제할 기억 키워드를 입력해 주세요. 예: /forget 앱스토어")
                return true
            }
            if argument.lowercased() == "all" {
                manager.clearKeyFacts()
                post("장기 기억을 모두 삭제했습니다.")
            } else {
                let removed = manager.forgetScopedFact(matching: argument, scope: nil)
                    + manager.forgetKeyFact(matching: argument)
                post(removed == 0 ? "일치하는 기억을 찾지 못했습니다." : "장기 기억 \(removed)개를 삭제했습니다.")
            }
            return true

        case "/open":
            guard !argument.isEmpty else {
                post("열 URL을 입력해 주세요. 예: /open https://apple.com")
                return true
            }
            if let url = openableURL(from: argument) {
                #if DEBUG
                NSWorkspace.shared.open(url)
                post("열었습니다: \(argument)")
                #else
                // Release (App Store) 빌드: 로컬 파일 경로 차단, URL만 허용
                if url.scheme == "http" || url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                    post("열었습니다: \(argument)")
                } else {
                    post("⚠️ 출시 빌드에서는 웹 URL만 열 수 있습니다.")
                }
                #endif
            } else {
                post("열 수 있는 URL 또는 파일 경로가 아닙니다.")
            }
            return true

        case "/fetch":
            guard !argument.isEmpty else {
                post("읽을 URL을 입력해 주세요. 예: /fetch https://example.com")
                return true
            }
            let policy = ToolPolicyDecision(
                needsTool: true,
                needsWeb: true,
                needsFinance: false,
                needsURLFetch: true,
                needsCurrentTime: true,
                recommendedTools: ["fetch_url"],
                reason: "URL 직접 읽기"
            )
            let evidence = await ToolEvidenceService.gather(for: argument, policy: policy)
            post(evidence.promptContext.isEmpty ? "URL에서 읽을 수 있는 본문을 찾지 못했습니다." : evidence.promptContext, sources: evidence.sources)
            return true

        case "/search":
            guard !argument.isEmpty else {
                post("검색어를 입력해 주세요. 예: /search 오늘 주요뉴스")
                return true
            }
            let policy = ToolPolicy.evaluate(argument + " 검색 출처")
            let evidence = await ToolEvidenceService.gather(for: argument, policy: policy)
            post(evidence.promptContext.isEmpty ? "검색 결과를 찾지 못했습니다." : evidence.promptContext, sources: evidence.sources)
            return true

        case "/schedule":
            guard let parsed = parseSchedule(argument) else {
                post("""
                사용법:
                /schedule 09:00 할 일          — 오늘(또는 내일) 09:00 실행
                /schedule 9시 30분 할 일       — 한국어 시간 표기
                /schedule 내일 09:00 할 일     — 내일 09:00 실행
                /schedule 매일 09:00 할 일     — 매일 반복
                /schedule 매주 월요일 09:00 할 일 — 매주 월요일 반복
                /schedule every 30m 할 일     — 30분마다 반복
                """)
                return true
            }
            // Destructive action policy check at registration time
            let (allowed, reason) = AutomationPolicy.isAllowed(parsed.prompt)
            guard allowed else {
                post("⚠️ 등록 실패: \(reason ?? "이 명령은 자동 실행에서 사용할 수 없습니다.")")
                return true
            }
            let task = manager.addAutomationTask(
                prompt: parsed.prompt,
                nextRunAt: parsed.nextRunAt,
                repeatInterval: parsed.repeatInterval,
                roomID: roomID
            )
            post("스케줄 업무를 추가했습니다. \(task.scheduleText) · \(task.title)")
            return true

        case "/tasks":
            let tasks = manager.automationTasks.sorted { $0.nextRunAt < $1.nextRunAt }
            guard !tasks.isEmpty else {
                post("등록된 스케줄 업무가 없습니다.")
                return true
            }
            let lines = tasks.enumerated().map { idx, task in
                let status = task.isEnabled ? "✅" : "⏸"
                let approval = task.requiresApproval ? " [승인필요]" : ""
                let shortId = String(task.id.uuidString.prefix(6))
                return "\(idx + 1). \(status) \(task.scheduleText) · \(task.title)\(approval)\n   ID: \(shortId) | \(task.prompt.prefix(50))"
            }.joined(separator: "\n")
            post("스케줄 업무\n\(lines)\n\n편집: /edit-task {ID} {옵션}  |  /cancel {번호}")
            return true

        case "/cancel":
            guard let number = Int(argument.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                post("취소할 번호를 입력해 주세요. 예: /cancel 1")
                return true
            }
            post(manager.cancelAutomationTask(displayIndex: number) ? "스케줄 업무 \(number)번을 삭제했습니다." : "해당 번호의 스케줄 업무를 찾지 못했습니다.")
            return true

        case "/edit-task":
            let editParts = argument.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard editParts.count >= 2 else {
                post("사용법: /edit-task {ID앞6자} {옵션}\n옵션: HH:MM | --disable | --enable | --approval on|off")
                return true
            }
            let taskResult = manager.editAutomationTask(idPrefix: String(editParts[0]), option: String(editParts[1]))
            post(taskResult)
            return true

        case "/approve":
            guard !argument.isEmpty else {
                post("승인할 작업 ID를 입력해 주세요. 예: /approve abc123")
                return true
            }
            let prefix = argument.lowercased()
            if let task = manager.automationTasks.first(where: { $0.id.uuidString.lowercased().hasPrefix(prefix) }) {
                manager.approveAutomationTask(id: task.id)
                post("✅ '\(task.title)' 작업을 승인하고 실행합니다.")
            } else {
                post("해당 ID의 승인 대기 작업을 찾지 못했습니다.")
            }
            return true

        case "/skip":
            guard !argument.isEmpty else {
                post("건너뜔 작업 ID를 입력해 주세요. 예: /skip abc123")
                return true
            }
            let prefix = argument.lowercased()
            if let task = manager.automationTasks.first(where: { $0.id.uuidString.lowercased().hasPrefix(prefix) }) {
                manager.skipAutomationTask(id: task.id)
                post("⏭️ '\(task.title)' 이번 회차를 건너뜠습니다.")
            } else {
                post("해당 ID의 작업을 찾지 못했습니다.")
            }
            return true

        case "/silent":
            guard let value = parseOnOff(argument) else {
                post("사용법: /silent on 또는 /silent off")
                return true
            }
            manager.isSilentMode = value
            post(value ? "무음 모드를 켰습니다." : "무음 모드를 껐습니다.")
            return true

        case "/voice":
            guard let value = parseOnOff(argument) else {
                post("사용법: /voice on 또는 /voice off")
                return true
            }
            manager.isVoiceMode = value
            post(value ? "음성 모드를 켰습니다." : "음성 모드를 껐습니다.")
            return true

        default:
            let target = currentAgent.map { "\($0.name)에게 " } ?? ""
            post("알 수 없는 명령어입니다. \(target)/help 를 입력하면 명령어 목록을 볼 수 있습니다.")
            return true
        }
    }

    static func buildPersonalResponsePolicy(
        for agent: AgentWindowManager.AgentConfig?,
        toolPolicy: ToolPolicyDecision
    ) -> String {
        let agentName = agent?.name ?? "에이전트"
        let agentID   = agent?.id ?? ""
        let role      = agent?.role ?? ""
        let specialty = agentPersonas[agentID]?.specialty ?? ""

        // 직업 전문성 힌트 (비어 있으면 생략)
        let specialtyHint: String
        if !specialty.isEmpty {
            specialtyHint = "\n- 당신의 핵심 전문 분야는 '\(specialty)'입니다. 이 분야 질문에는 특히 깊이 있고 구체적인 답변을 제공하세요."
        } else {
            specialtyHint = ""
        }
        let roleHint = role.isEmpty ? "" : "\n- 당신은 '\(role)' 역할입니다. 전문성을 자연스럽게 드러내세요."

        return """

        [개인창 응답 정책]
        - 지금은 팀 토론이 아니라 \(agentName)와 사용자의 1:1 대화입니다. 다른 캐릭터를 임의로 끼워 넣지 마세요.\(roleHint)\(specialtyHint)
        - 단순 확인, 잡담, 짧은 감정 반응은 1~3문장으로 짧게 답하세요.
        - 업무, 개발, 설계, 조사, 금융, 법률, 의사결정 질문은 근거-판단-다음 행동 순서로 답하세요.
        - 최신 정보나 금융/뉴스 질문은 제공된 도구 자료를 우선 사용하고, 모르면 추측하지 말고 확인 필요성을 말하세요.
        - 금융/투자 관련 답변은 참고 정보이며 최종 선택과 책임은 사용자 본인에게 있고 AI와 외부 데이터는 틀릴 수 있음을 짧게 밝혀야 합니다.
        - 현재 도구 정책: \(toolPolicy.reason)
        """
    }

    private static func parseOnOff(_ text: String) -> Bool? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on", "켜", "켜기", "true", "1":
            return true
        case "off", "꺼", "끄기", "false", "0":
            return false
        default:
            return nil
        }
    }

    private static func openableURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        let expanded = (trimmed as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return nil }
        return URL(fileURLWithPath: expanded)
    }

    private struct ParsedSchedule {
        let nextRunAt: Date
        let repeatInterval: TimeInterval?
        let prompt: String
    }

    private static func parseSchedule(_ text: String) -> ParsedSchedule? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        // ── 반복 간격: every 30m / every 2h ──
        if lower.hasPrefix("every ") {
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            // "every 30m 할 일" 형식 (3 parts)
            if parts.count == 3, let interval = parseInterval(String(parts[1])) {
                return ParsedSchedule(
                    nextRunAt: Date().addingTimeInterval(interval),
                    repeatInterval: interval,
                    prompt: String(parts[2])
                )
            }
            // "every day 09:00 할 일" 형식
            if parts.count >= 4, ["day", "days"].contains(parts[1].lowercased()) {
                let timePart = String(parts[2])
                let promptPart = parts.dropFirst(3).joined(separator: " ")
                if let date = parseTimeToken(timePart, dayOffset: 0) {
                    return ParsedSchedule(nextRunAt: date, repeatInterval: 86400, prompt: promptPart)
                }
            }
        }

        // ── 매일 / daily ──
        let dailyPrefixes = ["매일 ", "daily "]
        for prefix in dailyPrefixes {
            if lower.hasPrefix(prefix) {
                let rest = String(trimmed.dropFirst(prefix.count))
                if let parsed = parseTimeAndPrompt(rest, repeatInterval: 86400) { return parsed }
            }
        }

        // ── 매주 요일 ──
        let weekdays: [(prefix: String, weekday: Int)] = [
            ("매주 월요일", 2), ("매주 화요일", 3), ("매주 수요일", 4),
            ("매주 목요일", 5), ("매주 금요일", 6), ("매주 토요일", 7), ("매주 일요일", 1),
            ("every monday", 2), ("every tuesday", 3), ("every wednesday", 4),
            ("every thursday", 5), ("every friday", 6), ("every saturday", 7), ("every sunday", 1),
        ]
        for wd in weekdays where lower.hasPrefix(wd.prefix) {
            let rest = String(trimmed.dropFirst(wd.prefix.count)).trimmingCharacters(in: .whitespaces)
            if let parsed = parseTimeAndPrompt(rest, repeatInterval: 604800, weekday: wd.weekday) { return parsed }
        }

        // ── 내일 / tomorrow ──
        let tomorrowPrefixes = ["내일 ", "tomorrow "]
        for prefix in tomorrowPrefixes {
            if lower.hasPrefix(prefix) {
                let rest = String(trimmed.dropFirst(prefix.count))
                if let parsed = parseTimeAndPrompt(rest, dayOffset: 1) { return parsed }
            }
        }

        // ── 한국어 시간: N시 [M분] 내용 ──
        if let parsed = parseKoreanTime(trimmed) { return parsed }

        // ── HH:MM 내용 ──
        if let parsed = parseTimeAndPrompt(trimmed) { return parsed }

        return nil
    }

    /// `HH:MM 내용` 또는 `HH시 [MM분] 내용` 파싱 공통 경로
    private static func parseTimeAndPrompt(
        _ text: String,
        repeatInterval: TimeInterval? = nil,
        dayOffset: Int = 0,
        weekday: Int? = nil
    ) -> ParsedSchedule? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // HH:MM 패턴
        if let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})\s+(.+)$"#),
           let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
           let hourRange  = Range(match.range(at: 1), in: t),
           let minuteRange = Range(match.range(at: 2), in: t),
           let promptRange = Range(match.range(at: 3), in: t),
           let hour   = Int(t[hourRange]),
           let minute = Int(t[minuteRange]),
           hour >= 0, hour <= 23, minute >= 0, minute <= 59 {
            let prompt = String(t[promptRange])
            let date = makeDate(hour: hour, minute: minute, dayOffset: dayOffset, weekday: weekday)
            return ParsedSchedule(nextRunAt: date, repeatInterval: repeatInterval, prompt: prompt)
        }

        // 한국어 시간 (위임)
        if dayOffset != 0 || repeatInterval != nil {
            if let parsed = parseKoreanTime(t) {
                let date = makeDate(
                    hour: Calendar.current.component(.hour, from: parsed.nextRunAt),
                    minute: Calendar.current.component(.minute, from: parsed.nextRunAt),
                    dayOffset: dayOffset,
                    weekday: weekday
                )
                return ParsedSchedule(nextRunAt: date, repeatInterval: repeatInterval, prompt: parsed.prompt)
            }
        }
        return nil
    }

    /// `N시 [M분] 내용` 형식 파싱
    private static func parseKoreanTime(_ text: String) -> ParsedSchedule? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"^(\d{1,2})시(?:\s*(\d{1,2})분)?\s+(.+)$"#),
              let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..<t.endIndex, in: t)),
              let hourRange   = Range(match.range(at: 1), in: t),
              let hour = Int(t[hourRange]),
              hour >= 0, hour <= 23,
              let promptRange = Range(match.range(at: 3), in: t) else { return nil }

        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minRange = Range(match.range(at: 2), in: t),
           let m = Int(t[minRange]) {
            minute = m
        }
        let date = makeDate(hour: hour, minute: minute)
        return ParsedSchedule(nextRunAt: date, repeatInterval: nil, prompt: String(t[promptRange]))
    }

    /// 시/분 + dayOffset + 요일 기준 Date 생성.
    /// 해당 시각이 이미 지났으면 다음 날(또는 다음 해당 요일)로 이동.
    private static func makeDate(hour: Int, minute: Int, dayOffset: Int = 0, weekday: Int? = nil) -> Date {
        let cal = Calendar.current
        var base = Date()
        if dayOffset > 0 {
            base = cal.date(byAdding: .day, value: dayOffset, to: base) ?? base
        }
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        var date = cal.date(from: comps) ?? base

        if let wd = weekday {
            // 다음 해당 요일 찾기
            while cal.component(.weekday, from: date) != wd {
                date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            }
        } else if dayOffset == 0 && date <= Date() {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    /// "09:00" 같은 단독 시간 토큰을 Date로 변환 (오늘 기준, 지나면 내일)
    private static func parseTimeToken(_ token: String, dayOffset: Int = 0) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})$"#),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..<token.endIndex, in: token)),
              let hRange = Range(match.range(at: 1), in: token),
              let mRange = Range(match.range(at: 2), in: token),
              let h = Int(token[hRange]), let m = Int(token[mRange]),
              h >= 0, h <= 23, m >= 0, m <= 59 else { return nil }
        return makeDate(hour: h, minute: m, dayOffset: dayOffset)
    }

    private static func parseInterval(_ token: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+)(m|h)$"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..<token.endIndex, in: token)),
              let valueRange = Range(match.range(at: 1), in: token),
              let unitRange = Range(match.range(at: 2), in: token),
              let value = Double(token[valueRange]) else { return nil }
        return token[unitRange].lowercased() == "h" ? value * 3600 : value * 60
    }

    // MARK: - Memory Scope 파서

    /// `/remember` 인자에서 scope prefix를 파싱.
    /// - `@이름 내용` → character scope
    /// - `:global 내용` → global scope
    /// - `내용` → room scope (현재 방)
    static func parseMemoryScope(
        _ argument: String,
        roomID: UUID?
    ) -> (scope: AgentWindowManager.MemoryScope, content: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            let rest = String(trimmed.dropFirst())
            let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            let name = parts.first.map(String.init) ?? ""
            let content = parts.count > 1 ? String(parts[1]) : ""
            return (.character(name), content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if trimmed.lowercased().hasPrefix(":global ") {
            let content = String(trimmed.dropFirst(":global ".count))
            return (.global, content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let scope: AgentWindowManager.MemoryScope = roomID != nil ? .room(roomID!) : .global
        return (scope, trimmed)
    }
}

// MARK: - ChatAttachment 모델

struct ChatAttachment: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileSize: Int
    let type: AttachmentType
    let textContent: String?    // 텍스트/PDF/문서에서 추출한 텍스트
    let localPath: String?      // 로컬 저장 경로
    let timestamp: Date

    init(fileName: String, fileSize: Int, type: AttachmentType, textContent: String? = nil, localPath: String? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.fileSize = fileSize
        self.type = type
        self.textContent = textContent
        self.localPath = localPath
        self.timestamp = Date()
    }

    enum AttachmentType: String, Codable {
        case text       // .txt, .md, .swift, .py 등
        case image      // .png, .jpg, .gif 등
        case pdf        // .pdf
        case document   // .docx, .xlsx, .pptx 등
        case other

        static func from(fileName: String) -> AttachmentType {
            let ext = (fileName as NSString).pathExtension.lowercased()
            switch ext {
            case "txt", "md", "swift", "py", "js", "ts", "json", "yaml", "yml", "csv", "html", "css", "xml":
                return .text
            case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
                return .image
            case "pdf":
                return .pdf
            case "docx", "xlsx", "pptx", "doc", "xls", "ppt":
                return .document
            default:
                return .other
            }
        }
    }
}

// MARK: - 파일 내용 추출 유틸리티

struct FileContentExtractor {

    /// 파일 URL에서 텍스트 콘텐츠를 추출
    static func extractText(from url: URL) -> String? {
        let type = ChatAttachment.AttachmentType.from(fileName: url.lastPathComponent)

        switch type {
        case .text:
            return try? String(contentsOf: url, encoding: .utf8)
        case .pdf:
            return extractPDFText(from: url)
        default:
            return nil
        }
    }

    /// PDF에서 텍스트 추출 (PDFKit 사용)
    private static func extractPDFText(from url: URL) -> String? {
        guard let pdfDoc = PDFDocumentWrapper(url: url) else { return nil }
        return pdfDoc.string
    }

}

// MARK: - PDF 래퍼 (PDFKit 의존성 분리)

import PDFKit

struct PDFDocumentWrapper {
    let string: String?

    init?(url: URL) {
        guard let doc = PDFDocument(url: url) else { return nil }
        var text = ""
        for i in 0..<min(doc.pageCount, 20) {
            if let page = doc.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        self.string = text.isEmpty ? nil : String(text.prefix(5000))
    }
}
