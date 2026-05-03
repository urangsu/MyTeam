import Foundation

// MARK: - WorkflowEngine

final class WorkflowEngine {
    static let shared = WorkflowEngine()
    private init() {}

    /// WorkflowPlan을 순차 실행하여 WorkflowResult를 반환한다.
    /// - isRequired step 실패 시 즉시 중단.
    /// - isRequired=false step 실패 시 경고 후 계속 진행.
    func run(plan: WorkflowPlan, context: ToolExecutionContext) async -> WorkflowResult {
        var artifacts: [Artifact] = []
        var failedSteps: [(step: WorkflowStep, error: String)] = []
        let sessionID = context.sessionID

        AppLog.info("[WorkflowEngine] 시작: '\(plan.title)' (\(plan.steps.count)단계)")

        for step in plan.steps {
            AppLog.info("[WorkflowEngine] 실행 중: \(step.title) [\(step.toolName)]")
            let result = await ToolExecutor.shared.execute(
                step: step,
                context: context,
                sessionID: sessionID
            )

            if result.success {
                if let path = result.artifactPath {
                    artifacts.append(Artifact(
                        stepID: step.id,
                        stepTitle: step.title,
                        path: path,
                        output: result.output
                    ))
                }
            } else {
                let errMsg = result.error ?? "알 수 없는 오류"
                failedSteps.append((step: step, error: errMsg))

                if step.isRequired {
                    AppLog.error("[WorkflowEngine] 필수 단계 실패 → 중단: '\(step.title)' — \(errMsg)")
                    break
                } else {
                    AppLog.warning("[WorkflowEngine] 선택 단계 실패 → 계속: '\(step.title)' — \(errMsg)")
                }
            }
        }

        let summary = buildSummary(plan: plan, artifacts: artifacts, failedSteps: failedSteps)
        AppLog.info("[WorkflowEngine] 완료: \(artifacts.count)개 artifact, \(failedSteps.count)개 실패")
        return WorkflowResult(plan: plan, artifacts: artifacts, failedSteps: failedSteps, summary: summary)
    }

    private func buildSummary(
        plan: WorkflowPlan,
        artifacts: [Artifact],
        failedSteps: [(step: WorkflowStep, error: String)]
    ) -> String {
        var lines: [String] = []

        if failedSteps.isEmpty || !artifacts.isEmpty {
            lines.append("✅ 작업 완료: \(plan.title)")
        } else {
            lines.append("❌ 작업 실패: \(plan.title)")
        }

        if !artifacts.isEmpty {
            lines.append("📄 생성 파일:")
            artifacts.forEach { lines.append("  - \($0.path)") }
        }

        if !failedSteps.isEmpty {
            lines.append("⚠️ 실패 단계:")
            failedSteps.forEach { lines.append("  - \($0.step.title): \($0.error)") }
        }

        if let firstOutput = artifacts.first?.output, !firstOutput.isEmpty {
            lines.append("──────────────")
            lines.append(String(firstOutput.prefix(300)))
        }

        return lines.joined(separator: "\n")
    }
}
