import Foundation

// MARK: - WorkflowEngine

final class WorkflowEngine {
    static let shared = WorkflowEngine()
    private init() {}

    /// WorkflowPlan을 순차 실행하여 WorkflowResult를 반환한다.
    /// - isRequired step 실패 시 즉시 중단, 사용자 친화적 오류 메시지 포함.
    /// - isRequired=false step 실패 시 경고 후 계속 진행.
    func run(plan: WorkflowPlan, context: ToolExecutionContext) async -> WorkflowResult {
        var artifacts: [Artifact] = []
        var failedSteps: [(step: WorkflowStep, error: String)] = []
        let sessionID = context.sessionID

        AppLog.info("[WorkflowEngine] 시작: '\(plan.title)' (\(plan.steps.count)단계)")

        for step in plan.steps {
            AppLog.info("[WorkflowEngine] 실행: '\(step.title)' [\(step.toolName)]")
            let result = await ToolExecutor.shared.execute(
                step: step,
                context: context,
                sessionID: sessionID
            )

            if result.success {
                if let relPath = result.artifactPath {
                    let absPath = context.workspaceURL.appendingPathComponent(relPath).path
                    let artifact = Artifact(
                        stepID: step.id,
                        stepTitle: step.title,
                        path: relPath,
                        output: result.output
                    )
                    artifacts.append(artifact)

                    // ArtifactIndex 등록
                    let indexed = IndexedArtifact(
                        id: UUID().uuidString,
                        workflowID: sessionID,
                        title: step.title,
                        type: inferArtifactType(toolName: step.toolName),
                        filename: relPath,
                        path: absPath,
                        preview: String(result.output.prefix(200)),
                        createdAt: ISO8601DateFormatter().string(from: Date())
                    )
                    ArtifactStore.shared.registerArtifact(indexed)
                }
            } else {
                let rawErr = result.error ?? "알 수 없는 오류"
                let friendlyErr = friendlyError(rawErr, step: step)
                failedSteps.append((step: step, error: friendlyErr))

                if step.isRequired {
                    AppLog.error("[WorkflowEngine] 필수 단계 실패 → 중단: '\(step.title)' — \(rawErr)")
                    break
                } else {
                    AppLog.warning("[WorkflowEngine] 선택 단계 실패 → 계속: '\(step.title)' — \(rawErr)")
                }
            }
        }

        // 완료 알림 (Finder 열기 hook 등 UI에서 수신)
        let workspaceURL = context.workspaceURL
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .workflowCompleted,
                object: nil,
                userInfo: ["workspaceURL": workspaceURL]
            )
        }

        let summary = buildSummary(plan: plan, artifacts: artifacts,
                                   failedSteps: failedSteps, workspaceURL: workspaceURL)
        AppLog.info("[WorkflowEngine] 완료: \(artifacts.count)개 artifact, \(failedSteps.count)개 실패")
        return WorkflowResult(plan: plan, artifacts: artifacts, failedSteps: failedSteps, summary: summary)
    }

    // MARK: - Summary builder

    private func buildSummary(
        plan: WorkflowPlan,
        artifacts: [Artifact],
        failedSteps: [(step: WorkflowStep, error: String)],
        workspaceURL: URL
    ) -> String {
        var lines: [String] = []

        let allFailed = artifacts.isEmpty && !failedSteps.isEmpty
        lines.append(allFailed ? "❌ 작업 실패: \(plan.title)" : "✅ 작업 완료: \(plan.title)")

        if !artifacts.isEmpty {
            lines.append("📄 생성 파일:")
            artifacts.forEach { lines.append("  - \($0.path)") }
        }

        if !failedSteps.isEmpty {
            lines.append("⚠️ 실패 단계:")
            failedSteps.forEach { lines.append("  - \($0.step.title): \($0.error)") }
        }

        // 저장 위치 (Finder 열기 hook 준비)
        lines.append("📁 저장 위치: \(workspaceURL.path)")

        if let firstOutput = artifacts.first?.output, !firstOutput.isEmpty {
            lines.append("──────────────")
            lines.append(String(firstOutput.prefix(300)))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func inferArtifactType(toolName: String) -> ArtifactType {
        switch toolName {
        case "create_markdown_report":   return .report
        case "create_presentation_plan": return .presentation
        case "create_spreadsheet_plan":  return .spreadsheet
        case "write_text_file":          return .text
        default:                         return .other
        }
    }

    private func friendlyError(_ raw: String, step: WorkflowStep) -> String {
        if raw.contains("접근 거부") || raw.contains("forbidden") {
            return "'\(step.title)' 단계에서 접근이 거부되었습니다 (보안 정책)."
        }
        if raw.contains("입력 오류") || raw.contains("invalidInput") || raw.contains("필수") {
            return "'\(step.title)' 단계 입력값이 올바르지 않습니다. 요청을 더 구체적으로 작성해 주세요."
        }
        if raw.contains("도구를 찾을 수 없음") {
            return "'\(step.title)' 단계에서 '\(step.toolName)' 도구를 찾을 수 없습니다."
        }
        if raw.contains("금지") || raw.contains("blocked") {
            return "'\(step.title)' 단계는 현재 MVP에서 지원하지 않는 작업입니다."
        }
        return "'\(step.title)' 단계에서 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
    }
}
