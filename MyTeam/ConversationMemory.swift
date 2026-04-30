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

        func post(_ text: String, sources: [AgentWindowManager.SourceReference] = []) {
            manager.addChatLog(
                agentID: "system",
                agentName: "시스템",
                text: text,
                isUser: false,
                roomID: roomID,
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
                agentID: "system",
                agentName: "시스템",
                text: "현재 방 대화를 지웠습니다.",
                isUser: false,
                roomID: roomID
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
            let compacted = await compactHistory(messages: visibleMessages, maxMessages: 8)
            manager.replaceMessages(roomID: roomID, with: compacted)
            manager.addChatLog(
                agentID: "system",
                agentName: "시스템",
                text: "이전 대화를 요약하고 최근 흐름만 남겼습니다.",
                isUser: false,
                roomID: roomID
            )
            return true

        case "/remember":
            guard !argument.isEmpty else {
                post("저장할 내용을 같이 입력해 주세요. 예: /remember 사용자는 앱스토어 출시를 우선한다")
                return true
            }
            manager.addKeyFact(argument)
            post("장기 기억에 저장했습니다: \(argument)")
            return true

        case "/memory":
            if manager.keyFacts.isEmpty {
                post("저장된 장기 기억이 없습니다.")
            } else {
                let facts = manager.keyFacts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                post("저장된 장기 기억\n\(facts)")
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
                let removed = manager.forgetKeyFact(matching: argument)
                post(removed == 0 ? "일치하는 기억을 찾지 못했습니다." : "장기 기억 \(removed)개를 삭제했습니다.")
            }
            return true

        case "/open":
            guard !argument.isEmpty else {
                post("열 URL이나 파일 경로를 입력해 주세요. 예: /open https://apple.com")
                return true
            }
            if let url = openableURL(from: argument) {
                NSWorkspace.shared.open(url)
                post("열었습니다: \(argument)")
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
                post("사용법: /schedule 09:00 오늘 주요뉴스 알려줘 또는 /schedule every 30m NVDA 주가 확인")
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
                "\(idx + 1). \(task.scheduleText) · \(task.prompt)"
            }.joined(separator: "\n")
            post("스케줄 업무\n\(lines)")
            return true

        case "/cancel":
            guard let number = Int(argument.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                post("취소할 번호를 입력해 주세요. 예: /cancel 1")
                return true
            }
            post(manager.cancelAutomationTask(displayIndex: number) ? "스케줄 업무 \(number)번을 삭제했습니다." : "해당 번호의 스케줄 업무를 찾지 못했습니다.")
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
        return """

        [개인창 응답 정책]
        - 지금은 팀 토론이 아니라 \(agentName)와 사용자의 1:1 대화입니다. 다른 캐릭터를 임의로 끼워 넣지 마세요.
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

        if trimmed.lowercased().hasPrefix("every ") {
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let interval = parseInterval(String(parts[1])) else { return nil }
            return ParsedSchedule(
                nextRunAt: Date().addingTimeInterval(interval),
                repeatInterval: interval,
                prompt: String(parts[2])
            )
        }

        guard let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})\s+(.+)$"#),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
              let hourRange = Range(match.range(at: 1), in: trimmed),
              let minuteRange = Range(match.range(at: 2), in: trimmed),
              let promptRange = Range(match.range(at: 3), in: trimmed),
              let hour = Int(trimmed[hourRange]),
              let minute = Int(trimmed[minuteRange]),
              hour >= 0, hour <= 23, minute >= 0, minute <= 59 else {
            return nil
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var date = Calendar.current.date(from: components) else { return nil }
        if date <= Date() {
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return ParsedSchedule(nextRunAt: date, repeatInterval: nil, prompt: String(trimmed[promptRange]))
    }

    private static func parseInterval(_ token: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+)(m|h)$"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..<token.endIndex, in: token)),
              let valueRange = Range(match.range(at: 1), in: token),
              let unitRange = Range(match.range(at: 2), in: token),
              let value = Double(token[valueRange]) else { return nil }
        return token[unitRange].lowercased() == "h" ? value * 3600 : value * 60
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
