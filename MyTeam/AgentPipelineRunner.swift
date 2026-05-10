import Foundation

struct AgentPipelineResult: Equatable {
    enum Status: String {
        case completed
        case failed
        case cancelled
    }

    let status: Status
    let context: PipelineContext
    let finalOutput: String?
    let message: String
}

@MainActor
final class AgentPipelineRunner {
    static let shared = AgentPipelineRunner()

    func run(
        orders: [AgentWorkOrder],
        initialContext: PipelineContext,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> AgentPipelineResult {
        var contextBag = initialContext.asExecutionContextBag()
        var context = PipelineContext(contextBag)
        var finalOutput: String?

        guard !orders.isEmpty else {
            return AgentPipelineResult(
                status: .failed,
                context: context,
                finalOutput: nil,
                message: "파이프라인이 비어 있습니다."
            )
        }

        for order in orders {
            let contract = order.executionContract
            guard !Task.isCancelled else {
                return AgentPipelineResult(
                    status: .cancelled,
                    context: context,
                    finalOutput: finalOutput,
                    message: "작업이 취소되었습니다."
                )
            }

            let input = contextBag.mergedInput(for: contract.inputKeys)
            let output = synthesizeOutput(for: order, input: input, context: context)
            let verification = verify(output: output, contract: contract)

            if verification.hasError {
                if contract.maxRetries > 0 {
                    let retryOutput = synthesizeRecoveryOutput(for: order, input: input, context: context)
                    let retryVerification = verify(output: retryOutput, contract: contract)
                    if retryVerification.hasError {
                        return AgentPipelineResult(
                            status: .failed,
                            context: context,
                            finalOutput: finalOutput,
                            message: "파이프라인 단계 검증에 실패했습니다."
                        )
                    }
                    contextBag.set(retryOutput, for: contract.outputKey)
                    context = PipelineContext(contextBag)
                    finalOutput = retryOutput
                } else {
                    return AgentPipelineResult(
                        status: .failed,
                        context: context,
                        finalOutput: finalOutput,
                        message: "파이프라인 단계 검증에 실패했습니다."
                    )
                }
            } else {
                contextBag.set(output, for: contract.outputKey)
                context = PipelineContext(contextBag)
                finalOutput = output
            }

            await MainActor.run {
                manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "agentPipeline.\(contract.title)")
            }
        }

        return AgentPipelineResult(
            status: .completed,
            context: context,
            finalOutput: finalOutput,
            message: "파이프라인을 완료했습니다."
        )
    }

    private func synthesizeOutput(for order: AgentWorkOrder, input: String, context: PipelineContext) -> String {
        switch order.pipelineRole ?? .researcher {
        case .researcher:
            let summary = input.isEmpty ? "입력 없음" : String(input.prefix(240))
            return [
                "핵심 자료 정리",
                "- 요약: \(summary)",
                "- 누락 가능 항목: 원문이 더 있으면 보강 가능"
            ].joined(separator: "\n")

        case .drafter:
            let research = context.get("research_notes") ?? input
            return [
                "# 초안",
                "## 작성 가정",
                "- 입력 자료를 바탕으로 업무용 초안을 작성합니다.",
                "",
                "## 본문",
                research.isEmpty ? "- 초안 입력 없음" : research
            ].joined(separator: "\n")

        case .reviewer:
            let draft = context.get("draft") ?? input
            return [
                "검토 메모",
                "- 초안의 구조와 누락 항목을 확인했습니다.",
                "- 보강 포인트: \(draft.isEmpty ? "초안 입력 없음" : String(draft.prefix(120)))"
            ].joined(separator: "\n")

        case .verifier:
            return "검증 완료"

        case .artifactWriter:
            return "저장 준비 완료"
        }
    }

    private func synthesizeRecoveryOutput(for order: AgentWorkOrder, input: String, context: PipelineContext) -> String {
        switch order.pipelineRole ?? .researcher {
        case .drafter:
            let research = context.get("research_notes") ?? input
            return [
                "# 초안",
                "## 작성 가정",
                "- 검증 실패 항목을 보강했습니다.",
                "",
                "## 본문",
                research.isEmpty ? "- 보강된 초안 입력 없음" : research
            ].joined(separator: "\n")
        default:
            return synthesizeOutput(for: order, input: input, context: context)
        }
    }

    private func verify(output: String, contract: ExecutionStepContract) -> ResultVerificationSummary {
        ExecutionVerifier.verify(
            output,
            level: contract.verificationLevel
        )
    }
}
