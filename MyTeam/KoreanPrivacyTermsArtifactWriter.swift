import Foundation

// MARK: - KoreanPrivacyTermsArtifactWriter
enum KoreanPrivacyTermsArtifactWriter {

    /// 생성된 마크다운 콘텐츠를 Workspace에 저장하고 artifact로 등록한다.
    /// - Parameters:
    ///   - markdown: 생성된 마크다운 문서
    ///   - request: 원본 요청 (파일명 등)
    ///   - workflowID: 이 작업의 workflow ID (UUID 필수)
    ///   - roomID: 채팅 방 ID (UUID 필수, artifact 추적)
    /// - Throws: 파일 저장 실패 시 에러 발생
    /// - Returns: 저장된 artifact
    static func write(
        markdown: String,
        for request: KoreanPrivacyTermsRequest,
        workflowID: UUID,
        roomID: UUID
    ) async throws -> IndexedArtifact {
        // 1. Workspace에 파일 저장
        let filePath = await ArtifactStore.shared.workspaceURL.appendingPathComponent(request.filename).path

        do {
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[KoreanPrivacyTermsWriter] 파일 저장 실패: \(error)")
            throw error
        }

        // 2. 미리보기 (첫 200자)
        let preview = String(markdown.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // 3. Artifact 생성 및 등록 (UUID 기반 추적)
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: request.serviceName + " " + (request.documentType == .privacy ? "개인정보처리방침" : "이용약관"),
            type: .text,
            filename: request.filename,
            path: filePath,
            preview: preview,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        await ArtifactStore.shared.registerArtifact(artifact)
        AppLog.info("[KoreanPrivacyTermsWriter] artifact 저장: \(request.filename) workflowID=\(workflowID.uuidString.prefix(8)) roomID=\(roomID.uuidString.prefix(8))")

        return artifact
    }

    /// 안전 면책문구를 Markdown 상단에 추가한다.
    /// 법적 책임을 명확히 하고 전문가 검토 필수임을 강조한다.
    static func addSafetyDisclaimer(to content: String) -> String {
        let disclaimer = """
        > ⚠️ **본 문서는 AI가 생성한 출시 준비용 초안입니다**
        >
        > - 법적 자문이 아니며, 실제 배포 전에 **법무팀 또는 전문 변호사의 검토**가 필수입니다.
        > - 실제 수집 항목, SDK, 광고, 결제, 위치정보 사용 여부를 반드시 확인하세요.
        > - 법령 및 플랫폼 정책(App Store, Google Play, Apple Privacy Policy 등)은 변경될 수 있습니다.
        > - 기술 검수: 실제 구현과 정책이 일치하는지 확인하세요.
        >
        """

        return disclaimer + "\n\n" + content
    }
}
