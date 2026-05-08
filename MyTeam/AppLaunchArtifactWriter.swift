import Foundation

enum AppLaunchArtifactWriterError: LocalizedError {
    case emptyMarkdown

    var errorDescription: String? {
        switch self {
        case .emptyMarkdown:
            return "마크다운 내용이 비어 있습니다."
        }
    }
}

enum AppLaunchArtifactWriter {
    static func write(
        markdown: String,
        request: AppLaunchSkillRequest,
        workflowID: UUID,
        roomID: UUID,
        stepID: String
    ) async throws -> IndexedArtifact {
        let content = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw AppLaunchArtifactWriterError.emptyMarkdown }

        let finalMarkdown = addSafetyDisclaimer(to: content)
        let filename = AppLaunchSkillService.outputFilename(request)
        let filePath = await ArtifactStore.shared.workspaceURL.appendingPathComponent(filename).path

        do {
            try finalMarkdown.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[AppLaunchArtifactWriter] 파일 저장 실패: \(error.localizedDescription)")
            throw error
        }

        let preview = String(finalMarkdown.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: "\(request.appName) \(request.skillType.displayName)",
            type: .text,
            filename: filename,
            path: filePath,
            preview: preview,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        await ArtifactStore.shared.registerArtifact(artifact)
        AppLog.info("[AppLaunchArtifactWriter] artifact 저장: \(filename) workflowID=\(workflowID.uuidString.prefix(8)) roomID=\(roomID.uuidString.prefix(8)) stepID=\(stepID)")
        return artifact
    }

    static func completionMessage(for artifact: IndexedArtifact) -> String {
        """
        ✅ \(artifact.title)을 생성했습니다.

        파일: \(artifact.filename)
        📂 Workspace/Finder에서 열 수 있습니다.

        문서는 초안이므로 실제 앱 구조와 심사 기준에 맞게 수정해 주세요.
        """
    }

    static func failureMessage(reason: String) -> String {
        let sanitized = sanitizedFailureReason(reason)
        return """
        App Launch 문서 생성에 실패했습니다.

        이유: \(sanitized)
        다시 시도하거나 앱 이름과 핵심 기능을 더 구체적으로 알려주세요.
        """
    }

    static func addSafetyDisclaimer(to content: String) -> String {
        let disclaimer = "본 문서는 출시 준비용 초안입니다. 실제 앱 구조, 플랫폼 정책, 심사 기준에 맞게 수정해야 합니다."
        if content.contains(disclaimer) {
            return content
        }

        return """
        \(content)

        ---
        \(disclaimer)
        """
    }

    private static func sanitizedFailureReason(_ reason: String) -> String {
        let cleaned = reason
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "알 수 없는 오류"
        }
        return String(cleaned.prefix(120))
    }
}
