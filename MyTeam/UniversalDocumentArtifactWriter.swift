import Foundation

enum UniversalDocumentArtifactWriterError: LocalizedError {
    case emptyMarkdown

    var errorDescription: String? {
        switch self {
        case .emptyMarkdown:
            return "마크다운 내용이 비어 있습니다."
        }
    }
}

enum UniversalDocumentArtifactWriter {
    static func writeMarkdown(
        content: String,
        request: UniversalDocumentSkillRequest,
        roomID: UUID,
        manager: AgentWindowManager,
        resultStatus: ToolResultStatus = .succeeded
    ) async throws -> IndexedArtifact {
        let markdown = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !markdown.isEmpty else { throw UniversalDocumentArtifactWriterError.emptyMarkdown }

        // ArtifactPersistencePolicy: 저장 가능 여부 확인
        guard ArtifactPersistencePolicy.shouldPersist(resultStatus: resultStatus) else {
            AppLog.warning("[UniversalDocumentArtifactWriter] artifact 저장 skipped: status=\(resultStatus.rawValue)")
            throw UniversalDocumentArtifactWriterError.emptyMarkdown
        }

        let filename = UniversalDocumentSkillService.outputFilename(for: request)
        let title = UniversalDocumentSkillService.documentTitle(for: request)
        let filePath = await ArtifactStore.shared.workspaceURL.appendingPathComponent(filename).path

        do {
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[UniversalDocumentArtifactWriter] 파일 저장 실패: \(error.localizedDescription)")
            throw error
        }

        let preview = String(markdown.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        let workflowID = await MainActor.run { manager.currentWorkflowID } ?? UUID()
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: title,
            type: .text,
            filename: filename,
            path: filePath,
            preview: preview,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        await ArtifactStore.shared.registerArtifact(artifact)

        // ArtifactPersistencePolicy: index 추가 여부 확인
        if ArtifactPersistencePolicy.shouldIndexArtifact(resultStatus: resultStatus) {
            // RecentArtifactIndex에 추가 (metadata only)
            let contentHash = StableContentHash.sha256Hex(markdown)
            let entry = RecentArtifactIndexEntry(
                artifactID: artifact.id,
                roomID: roomID,
                filename: filename,
                artifactType: "text",
                createdAt: Date(),
                contentHash: contentHash,
                fileSizeBytes: Int64(markdown.utf8.count)
            )
            manager.addRecentArtifactIndexEntry(entry)

            // RecentArtifactIndexPersistence에 저장
            await MainActor.run {
                manager.roomRuntimeStore.saveRecentArtifactIndex()
            }

            AppLog.info("[UniversalDocumentArtifactWriter] artifact 저장 & indexed & persisted: \(filename) workflowID=\(workflowID.uuidString.prefix(8)) roomID=\(roomID.uuidString.prefix(8))")
        } else {
            AppLog.info("[UniversalDocumentArtifactWriter] artifact 저장만 (no index): \(filename) status=\(resultStatus.rawValue)")
        }

        return artifact
    }

    static func completionMessage(
        artifact: IndexedArtifact,
        request: UniversalDocumentSkillRequest,
        verification: ResultVerificationSummary?
    ) -> String {
        let isFileBased = request.sourceName?.isEmpty == false
        var lines = [
            isFileBased ? "✅ 파일 기반 문서 초안을 만들었습니다." : "✅ 문서 초안을 만들었습니다.",
            "",
            "유형: \(request.type.displayName)",
            "파일: \(artifact.filename)"
        ]

        if let sourceName = request.sourceName, !sourceName.isEmpty {
            lines.append("원본: \(sourceName)")
        }

        lines.append("📂 Workspace/Finder에서 열 수 있습니다.")

        if let verification, !verification.issues.isEmpty {
            let warningCount = verification.issues.filter { $0.severity == .warning }.count
            if warningCount > 0 {
                lines.append("")
                lines.append("검토 메모: \(warningCount)개 항목을 한 번 더 다듬어 보시면 좋습니다.")
            }
        }

        lines.append("")
        lines.append("다음에는 \"표로 다시 정리해줘\"처럼 이어서 요청할 수 있습니다.")
        return lines.joined(separator: "\n")
    }

    static func failureMessage(error: Error, request: UniversalDocumentSkillRequest) -> String {
        let reason = sanitizedFailureReason(error.localizedDescription)
        return """
        \(request.type.displayName) 생성에 실패했습니다.

        이유: \(reason)
        다시 시도하거나 요청을 조금 더 구체적으로 알려주세요.
        """
    }

    private static func sanitizedFailureReason(_ reason: String) -> String {
        let cleaned = reason
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "알 수 없는 오류" }
        return String(cleaned.prefix(120))
    }
}
