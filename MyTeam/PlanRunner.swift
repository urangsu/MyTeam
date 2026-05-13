import Foundation

@MainActor
final class PlanRunner {
    static let shared = PlanRunner()

    private func makeFailure(
        _ message: String,
        reason: PlanExecutionResult.FailureReason
    ) -> PlanExecutionResult {
        PlanExecutionResult(
            status: .failed,
            message: message,
            artifactID: nil,
            failureReason: reason
        )
    }

    func runUniversalDocumentPlan(
        _ plan: WorkPlan,
        request: UniversalDocumentSkillRequest,
        roomID: UUID,
        workflowID: UUID,
        manager: AgentWindowManager,
        allowedScopes: Set<ToolScope>
    ) async -> PlanExecutionResult {
        guard plan.workflowKind == .universalDocument else {
            return makeFailure(
                "지원하지 않는 실행 계획입니다.",
                reason: .safetyBlocked
            )
        }

        await MainActor.run {
            manager.currentWorkflowID = workflowID
            manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "planRunner.started")
        }

        var context = ExecutionContextBag()
        context.set(request.userMessage, for: "user_message")
        context.set(request.title, for: "document_title")
        context.set(request.topic, for: "topic")
        context.set(allowedScopes.map(\.rawValue).sorted().joined(separator: ","), for: "allowed_scopes")

        let prompt = UniversalDocumentSkillService.buildPrompt(for: request)
        var draftMarkdown = ""
        var verifiedMarkdown = ""
        var verification: ResultVerificationSummary?

        for step in plan.steps {
            let contract = step.executionContract

            guard !Task.isCancelled else {
                return PlanExecutionResult(
                    status: .cancelled,
                    message: "작업이 취소되었습니다.",
                    artifactID: nil,
                    failureReason: .cancelled
                )
            }

            switch step.kind {
            case .llmGenerate:
                await MainActor.run {
                    manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "planRunner.generating")
                }

                guard AICallBudgetManager.shared.requestCall(.universalDocumentGen) else {
                    return PlanExecutionResult(
                        status: .failed,
                        message: AICallBudgetManager.shared.blockedMessage(for: .universalDocumentGen),
                        artifactID: nil,
                        failureReason: .budgetBlocked
                    )
                }

                do {
                    let generated = try await AIService.shared.getResponse(
                        text: prompt,
                        agentID: "planner",
                        chatHistory: []
                    )
                    draftMarkdown = generated.text
                    context.set(draftMarkdown, for: "draft_markdown")
                } catch {
                    return makeFailure(
                        UniversalDocumentArtifactWriter.failureMessage(error: error, request: request),
                        reason: .recoverableRuntimeError
                    )
                }

            case .verifyMarkdown:
                await MainActor.run {
                    manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "planRunner.verifying")
                }

                // Use document-type-specific verification
                verification = ExecutionVerifier.verify(
                    draftMarkdown,
                    level: contract.verificationLevel,
                    sourceText: request.sourceText,
                    documentType: request.type,
                    requiredSections: UniversalDocumentSkillService.requiredSections(for: request.type)
                )

                if let currentVerification = verification, currentVerification.hasError {
                    // 실패 정책: error → 저장 금지 + recovery 1회
                    if ResultRecoveryPolicy.shouldRetryUniversalDocument(verification: currentVerification, attempt: 1) {
                        guard AICallBudgetManager.shared.requestCall(.universalDocumentRepair) else {
                            return PlanExecutionResult(
                                status: .failed,
                                message: AICallBudgetManager.shared.blockedMessage(for: .universalDocumentRepair),
                                artifactID: nil,
                                failureReason: .budgetBlocked
                            )
                        }
                        do {
                            let repaired = try await AIService.shared.getResponse(
                                text: prompt,
                                agentID: "planner",
                                chatHistory: []
                            )
                            draftMarkdown = repaired.text
                            context.set(draftMarkdown, for: "draft_markdown")
                            verification = ExecutionVerifier.verify(
                                draftMarkdown,
                                level: contract.verificationLevel,
                                sourceText: request.sourceText,
                                documentType: request.type,
                                requiredSections: UniversalDocumentSkillService.requiredSections(for: request.type)
                            )
                        } catch {
                            return makeFailure(
                                UniversalDocumentArtifactWriter.failureMessage(error: error, request: request),
                                reason: .recoverableRuntimeError
                            )
                        }
                    }
                }

                // 실패 정책: recovery 실패 → 사용자 안내 + index 금지
                guard let verification, !verification.hasError else {
                    AppLog.error("[PlanRunner] verification failed: \(verification?.issues.map { $0.message }.joined(separator: ", ") ?? "unknown error")")
                    return PlanExecutionResult(
                        status: .failed,
                        message: ResultRecoveryPolicy.failureMessage(),
                        artifactID: nil,
                        failureReason: .verificationFailed
                    )
                }

                // 실패 정책: warning → 저장 가능 + 검토 메모
                if !verification.issues.isEmpty {
                    let warningCount = verification.issues.filter { $0.severity == .warning }.count
                    AppLog.warning("[PlanRunner] verification warnings=\(warningCount): \(verification.issues.filter { $0.severity == .warning }.map { $0.message }.joined(separator: ", "))")
                }
                verifiedMarkdown = draftMarkdown
                context.set(verifiedMarkdown, for: "verified_markdown")

            case .persistArtifact:
                await MainActor.run {
                    manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "planRunner.saving")
                }

                do {
                    let artifact = try await UniversalDocumentArtifactWriter.writeMarkdown(
                        content: verifiedMarkdown,
                        request: request,
                        roomID: roomID,
                        manager: manager,
                        resultStatus: .succeeded
                    )
                    if let artifactUUID = UUID(uuidString: artifact.id) {
                        await MainActor.run {
                            manager.updateRoomGoalContext(roomID: roomID, recentArtifactID: artifactUUID)
                        }
                    }
                    context.set(artifact.id, for: "artifact_id")
                    context.set(artifact.filename, for: "artifact_filename")
                    context.set(artifact.title, for: "artifact_title")
                    context.set(artifact.relativePath, for: "artifact_path")
                } catch {
                    return makeFailure(
                        UniversalDocumentArtifactWriter.failureMessage(error: error, request: request),
                        reason: .recoverableRuntimeError
                    )
                }

            case .report:
                guard
                    let artifactIDString = context.get("artifact_id"),
                    let artifactFilename = context.get("artifact_filename"),
                    let artifactTitle = context.get("artifact_title"),
                    let artifactPath = context.get("artifact_path")
                else {
                    return PlanExecutionResult(
                        status: .failed,
                        message: "결과물을 저장하지 못했습니다.",
                        artifactID: nil,
                        failureReason: .recoverableRuntimeError
                    )
                }

                let artifact = IndexedArtifact(
                    id: artifactIDString,
                    workflowID: workflowID.uuidString,
                    title: artifactTitle,
                    type: .text,
                    filename: artifactFilename,
                    relativePath: artifactPath,
                    preview: String(verifiedMarkdown.prefix(200)),
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    roomID: roomID.uuidString
                )

                let message = UniversalDocumentArtifactWriter.completionMessage(
                    artifact: artifact,
                    request: request,
                    verification: verification
                )
                await MainActor.run {
                    manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: nil)
                }
                return PlanExecutionResult(
                    status: .completed,
                    message: message,
                    artifactID: UUID(uuidString: artifact.id),
                    failureReason: .none
                )

            default:
                continue
            }
        }

        return PlanExecutionResult(
            status: .failed,
            message: "결과물을 만들지 못했습니다.",
            artifactID: nil,
            failureReason: .recoverableRuntimeError
        )
    }
}
