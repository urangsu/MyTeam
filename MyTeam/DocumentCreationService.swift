import Foundation

// MARK: - DocumentCreationService
// Round 164A-180Z: Document Creation Hub
// API key가 없어도 로컬 템플릿으로 결과를 생성
// artifactIDs를 ChatLog와 연결

enum DocumentCreationService {

    /// 로컬 fallback 문서를 생성하고 artifact로 저장
    /// - Returns: (artifact, result text for chat)
    static func createLocalDocument(
        type: DocumentCreationType,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> (artifact: IndexedArtifact, resultText: String)? {
        let template = LocalDocumentTemplate.generate(for: type)
        let title = LocalDocumentTemplate.generateTitle(for: type)
        let filename = sanitizeFilename("\(title)_\(type.skillType.filenameSuffix).md")

        let workflowID = UUID()
        let contentHash = StableContentHash.sha256Hex(template)
        let preview = String(template.prefix(200))
        let createdAtString = ISO8601DateFormatter().string(from: Date())

        // artifact 생성 (AppLaunchArtifactWriter 패턴 참고)
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: "\(title)",
            type: .text,
            filename: filename,
            relativePath: filename,
            preview: preview,
            createdAt: createdAtString,
            contentHash: contentHash,
            fileSizeBytes: Int64(template.count),
            roomID: roomID.uuidString
        )

        // Artifact Store에 저장
        await ArtifactStore.shared.registerArtifact(artifact)

        // Recent artifact index에 추가
        let entry = RecentArtifactIndexEntry(
            artifactID: artifact.id,
            roomID: roomID,
            filename: filename,
            artifactType: "text",
            createdAt: Date(),
            contentHash: contentHash,
            fileSizeBytes: Int64(template.count)
        )
        await MainActor.run {
            manager.addRecentArtifactIndexEntry(entry)
        }

        // Chat에 표시할 결과 텍스트
        let resultText = """
        # \(type.title) 초안을 만들었습니다.

        \(type.description)

        기본 템플릿을 바탕으로 만들었으니 내용을 편집해서 사용하세요.
        """

        return (artifact, resultText)
    }

    /// AI provider가 있을 때 풍부한 문서 생성
    /// UniversalDocumentSkillService를 통해 처리
    static func detectDocumentCreationIntent(from message: String) -> DocumentCreationType? {
        let lower = message.lowercased()

        // "문서 만들기" → hub 진입점
        if lower.contains("문서 만들") || lower == "문서 만들기" {
            return nil  // Hub 진입, 타입 선택 필요
        }

        // 특정 타입 감지
        let meetingKeywords = ["회의록", "meeting minutes", "회의 내용", "회의 정리"]
        if meetingKeywords.contains(where: { lower.contains($0) }) {
            return .meetingMinutes
        }

        let checklistKeywords = ["체크리스트", "checklist", "체크", "준비 확인"]
        if checklistKeywords.contains(where: { lower.contains($0) }) {
            return .checklist
        }

        let reportKeywords = ["보고서", "report", "보고", "초안"]
        if reportKeywords.contains(where: { lower.contains($0) }) {
            return .reportDraft
        }

        return nil
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name
            .components(separatedBy: invalidChars)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
    }
}
