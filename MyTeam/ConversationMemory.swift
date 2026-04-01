import Foundation
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
            isSystem: false
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
