import Foundation

// MARK: - KoreanPrivacyTermsArtifactWriter
enum KoreanPrivacyTermsArtifactWriter {

    /// 생성된 마크다운 콘텐츠를 Workspace에 저장하고 artifact로 등록한다.
    /// - Parameters:
    ///   - content: 생성된 마크다운 문서
    ///   - request: 원본 요청 (파일명 등)
    ///   - workflowID: 이 작업의 workflow ID
    /// - Returns: 저장된 artifact 또는 nil (실패 시)
    static func saveArtifact(
        content: String,
        for request: KoreanPrivacyTermsRequest,
        workflowID: String
    ) async -> IndexedArtifact? {
        // 1. Workspace에 파일 저장
        let filePath = await ArtifactStore.shared.workspaceURL.appendingPathComponent(request.filename).path

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[KoreanPrivacyTermsWriter] 파일 저장 실패: \(error)")
            return nil
        }

        // 2. 미리보기 (첫 200자)
        let preview = String(content.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // 3. Artifact 생성 및 등록
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID,
            title: request.serviceName + " " + (request.documentType == .privacy ? "개인정보처리방침" : "이용약관"),
            type: .text,
            filename: request.filename,
            path: filePath,
            preview: preview,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        await ArtifactStore.shared.registerArtifact(artifact)
        AppLog.info("[KoreanPrivacyTermsWriter] artifact 저장: \(request.filename)")

        return artifact
    }

    /// 맞춤법, 안내문구 등을 Markdown에 추가한다.
    /// (현재 약간의 경고나 안내를 헤더로 추가)
    static func addSafetyDisclaimer(to content: String) -> String {
        let disclaimer = """
        > ⚠️ **법적 책임 고지**
        >
        > 이 문서는 AI가 생성한 샘플입니다. 법적 조언이 아니며, 실제 배포 전에 **법무팀 또는 전문 변호사의 검토**를 받으세요.
        > 규제 기관 가이드, 업계 표준, 귀사의 정책에 맞게 조정이 필요합니다.
        > - **개인정보보호법** 준수
        > - 서비스 약관 및 정책 반영
        > - 고객 피드백 반영
        >
        """

        return disclaimer + "\n\n" + content
    }
}
