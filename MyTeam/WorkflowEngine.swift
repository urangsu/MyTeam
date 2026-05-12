import Foundation

// MARK: - WorkflowEngine

final class WorkflowEngine {
    static let shared = WorkflowEngine()
    private init() {}

    /// WorkflowPlan을 순차 실행하여 WorkflowResult를 반환한다.
    /// - isRequired step 실패 시 즉시 중단, 사용자 친화적 오류 메시지 포함.
    /// - isRequired=false step 실패 시 경고 후 계속 진행.
    /// - invalidInput 실패 시 1회 LLM self-repair 후 재실행.
    func run(plan: WorkflowPlan, context: ToolExecutionContext, allowedScopes: Set<ToolScope> = [.chatBasic, .artifactGeneration]) async -> WorkflowResult {
        var artifacts: [Artifact] = []
        var failedSteps: [(step: WorkflowStep, error: String)] = []
        let sessionID = context.sessionID
        let workflowID = context.workflowID
        let roomID = context.roomID

        AppLog.info("[WorkflowEngine] 시작: '\(plan.title)' (\(plan.steps.count)단계) allowedScopes=\(allowedScopes.map { $0.rawValue }.sorted())")

        for step in plan.steps {
            AppLog.info("[WorkflowEngine] 실행: '\(step.title)' [\(step.toolName)]")
            var executedStep = step  // repair 성공 시 repairedStep으로 교체

            // ── step 시작 기록 ──
            let stepRecord = StepExecutionRecord(stepID: step.id, toolName: step.toolName,
                                                  inputSummary: step.title)
            await MainActor.run { WorkflowRunStore.shared.recordStep(workflowID: workflowID, step: stepRecord) }
            await AgentEventBus.shared.publish(.toolCallStarted(workflowID: workflowID, stepID: step.id, toolName: step.toolName))

            let stepStart = Date()
            var result = await ToolExecutionLayer.execute(
                step: step,
                context: context,
                sessionID: sessionID,
                allowedScopes: allowedScopes
            )

            // invalidInput 실패 → step 단위 self-repair 1회 시도
            if !result.success, let rawErr = result.error, isInputError(rawErr) {
                AppLog.info("[WorkflowEngine] 입력 오류 감지 → step 수정 시도: '\(step.title)'")
                if let repairedStep = await repairStep(step, error: rawErr, plan: plan, workflowID: workflowID) {
                    AppLog.info("[WorkflowEngine] step 수정 완료 → 재실행: '\(step.title)'")
                    executedStep = repairedStep
                    result = await ToolExecutionLayer.execute(
                        step: repairedStep,
                        context: context,
                        sessionID: sessionID,
                        allowedScopes: allowedScopes
                    )
                }
            }

            let durationMs = Int(Date().timeIntervalSince(stepStart) * 1000)

            if result.status == .succeeded {
                // ── step 성공 기록 ──
                await MainActor.run {
                    WorkflowRunStore.shared.updateStep(workflowID: workflowID, stepID: executedStep.id) { rec in
                        rec.status = .completed
                        rec.endedAt = Date()
                        rec.outputSummary = String(result.output.prefix(100))
                    }
                }
                await AgentEventBus.shared.publish(.toolCallFinished(workflowID: workflowID, stepID: executedStep.id,
                                                                     toolName: executedStep.toolName, durationMs: durationMs, success: true))

                if let relPath = result.artifactPath,
                   ArtifactPersistencePolicy.shouldPersist(resultStatus: result.status) {
                    let absPath = context.workspaceURL.appendingPathComponent(relPath).path
                    // artifact 기록은 실제 실행된 step(executedStep) 기준
                    let artifact = Artifact(
                        stepID: executedStep.id,
                        stepTitle: executedStep.title,
                        path: relPath,
                        output: result.output
                    )
                    artifacts.append(artifact)

                    // ArtifactIndex 등록 (executedStep 기준)
                    let indexed = IndexedArtifact(
                        id: UUID().uuidString,
                        workflowID: sessionID,
                        title: executedStep.title,
                        type: inferArtifactType(toolName: executedStep.toolName),
                        filename: relPath,
                        path: absPath,
                        preview: String(result.output.prefix(200)),
                        createdAt: ISO8601DateFormatter().string(from: Date())
                    )
                    await ArtifactStore.shared.registerArtifact(indexed)
                    await MainActor.run { WorkflowRunStore.shared.addArtifact(workflowID: workflowID, relativePath: relPath) }
                    await AgentEventBus.shared.publish(.artifactCreated(workflowID: workflowID, roomID: roomID, path: relPath))
                }
            } else {
                let rawErr = result.error ?? "알 수 없는 오류"
                let friendlyErr = friendlyError(rawErr, step: executedStep)
                failedSteps.append((step: executedStep, error: friendlyErr))

                // ── step 실패 기록 ──
                await MainActor.run {
                    WorkflowRunStore.shared.updateStep(workflowID: workflowID, stepID: executedStep.id) { rec in
                        rec.status = .failed
                        rec.endedAt = Date()
                        rec.errorMessage = rawErr
                    }
                    WorkflowRunStore.shared.recordError(workflowID: workflowID, stepID: executedStep.id, message: rawErr)
                }
                await AgentEventBus.shared.publish(.toolCallFinished(workflowID: workflowID, stepID: executedStep.id,
                                                                     toolName: executedStep.toolName, durationMs: durationMs, success: false))

                if executedStep.isRequired {
                    AppLog.error("[WorkflowEngine] 필수 단계 실패 → 중단: '\(executedStep.title)' — \(rawErr)")
                    break
                } else {
                    AppLog.warning("[WorkflowEngine] 선택 단계 실패 → 계속: '\(executedStep.title)' — \(rawErr)")
                }
            }
        }

        // 완료 알림 (workflowID 포함 — AgentWindowManager가 해당 workflow만 필터하는 데 사용)
        // 키 이름: "workflowID" (sessionID라는 이름을 쓰지 않는다 — AICallBudgetManager.sessionID와 혼동 방지)
        let workspaceURL = context.workspaceURL
        let completedArtifacts = artifacts
        let completedWorkflowID = sessionID
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .workflowCompleted,
                object: nil,
                userInfo: [
                    "workspaceURL": workspaceURL,
                    "artifacts": completedArtifacts,
                    "workflowID": completedWorkflowID
                ]
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
            lines.append("📂 Finder에서 열기 가능: \(workspaceURL.path)")
        }

        if !failedSteps.isEmpty {
            lines.append("⚠️ 실패 단계:")
            failedSteps.forEach { lines.append("  - \($0.step.title): \($0.error)") }
        }

        if !artifacts.isEmpty {
            lines.append("📁 저장 위치: \(workspaceURL.path)")
        }

        if let firstOutput = artifacts.first?.output, !firstOutput.isEmpty {
            lines.append("──────────────")
            lines.append(String(firstOutput.prefix(300)))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Step-level self-repair

    private func isInputError(_ error: String) -> Bool {
        error.contains("입력 오류") || error.contains("invalidInput") || error.contains("필수")
    }

    private func repairStep(
        _ step: WorkflowStep,
        error: String,
        plan: WorkflowPlan,
        workflowID: UUID
    ) async -> WorkflowStep? {
        let prompt = buildStepRepairPrompt(step: step, error: error, plan: plan)
        do {
            let (jsonText, _) = try await AIService.shared.getResponse(
                text: prompt,
                agentID: "planner",
                chatHistory: []
            )
            let cleaned = extractJSON(from: jsonText)
            guard let data = cleaned.data(using: .utf8) else { return nil }
            let repaired = try JSONDecoder().decode(WorkflowStep.self, from: data)
            guard repaired.id == step.id,
                  repaired.toolName == step.toolName,
                  repaired.title == step.title,
                  repaired.isRequired == step.isRequired,
                  repaired.dependsOn == step.dependsOn,
                  repaired.riskLevel == step.riskLevel else {
                AppLog.warning("[WorkflowEngine] step repair contract mutation blocked: \(step.title)")
                await MainActor.run {
                    WorkflowRunStore.shared.recordError(
                        workflowID: workflowID,
                        stepID: step.id,
                        message: "step repair contract mutation blocked",
                        failureCode: "step_repair_contract_mutation_blocked"
                    )
                }
                return nil
            }
            return WorkflowStep(
                id: step.id,
                toolName: step.toolName,
                title: step.title,
                input: repaired.input,
                isRequired: step.isRequired,
                dependsOn: step.dependsOn,
                riskLevel: step.riskLevel
            )
        } catch {
            AppLog.warning("[WorkflowEngine] step 수정 실패: \(error.localizedDescription)")
            return nil
        }
    }

    private func buildStepRepairPrompt(step: WorkflowStep, error: String, plan: WorkflowPlan) -> String {
        let inputJSON = (try? String(data: JSONEncoder().encode(step.input), encoding: .utf8)) ?? "{}"

        // 도구 inputSchema 설명
        let schemaDesc: String
        if let tool = ToolRegistry.shared.lookup(name: step.toolName) {
            let params = tool.inputSchema
                .sorted { $0.key < $1.key }
                .map { "  - \($0.key): \($0.value)" }
                .joined(separator: "\n")
            schemaDesc = "도구 파라미터 설명:\n\(params)"
        } else {
            schemaDesc = ""
        }

        // 복잡한 JSON 파라미터에 대한 형식 힌트
        let formatHint: String
        switch step.toolName {
        case "create_presentation_plan":
            formatHint = """
            slides_json 형식 (반드시 JSON 문자열로 전달):
            "[{\\"title\\":\\"슬라이드 제목\\",\\"content\\":\\"슬라이드 내용\\"},...]"
            (배열 안에 title/content 키를 가진 객체 나열)
            """
        case "create_spreadsheet_plan":
            formatHint = """
            data_json 형식 (반드시 JSON 문자열로 전달):
            "{\\"headers\\":[\\"항목\\",\\"값\\"],\\"rows\\":[[\\"A\\",\\"1\\"],[\\"B\\",\\"2\\"]]}"
            (headers 배열 + rows 2차원 배열 필수)
            """
        default:
            formatHint = ""
        }

        return """
        아래 워크플로우 단계가 입력 오류로 실패했습니다.
        JSON 블록(```json ... ```)으로 수정된 단계만 반환하세요. 다른 설명은 없어야 합니다.
        수정 허용 범위는 input만입니다. id, toolName, title, isRequired, dependsOn, riskLevel은 변경하지 마세요.

        워크플로우 제목: \(plan.title)
        단계 제목: \(step.title)
        도구: \(step.toolName)
        현재 입력값: \(inputJSON)
        오류 메시지: \(error)

        \(schemaDesc)
        \(formatHint.isEmpty ? "" : "\n\(formatHint)")
        수정된 단계 JSON 스키마:
        {
          "id": "\(step.id)",
          "toolName": "\(step.toolName)",
          "title": "\(step.title)",
          "input": {"param": "수정된 값"},
          "isRequired": \(step.isRequired),
          "dependsOn": [],
          "riskLevel": "\(step.riskLevel.rawValue)"
        }
        """
    }

    private func extractJSON(from text: String) -> String {
        if let s = text.range(of: "```json"),
           let e = text[s.upperBound...].range(of: "```") {
            return String(text[s.upperBound..<e.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = text.range(of: "```"),
           let e = text[s.upperBound...].range(of: "```") {
            return String(text[s.upperBound..<e.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
            return String(text[s...e])
        }
        return text
    }

    // MARK: - Helpers

    private func inferArtifactType(toolName: String) -> ArtifactType {
        switch toolName {
        case "create_markdown_report":                return .report
        case "create_presentation_plan":              return .presentation
        case "generate_pptx":                         return .presentation
        case "create_spreadsheet_plan":               return .spreadsheet
        case "generate_xlsx":                         return .spreadsheet
        case "write_text_file":                       return .text
        case "create_google_slides",
             "create_google_sheets":                  return .cloud
        default:                                      return .other
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
