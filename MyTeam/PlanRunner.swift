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

        var context: [String: String] = [
            "user_message": request.userMessage,
            "document_title": request.title,
            "topic": request.topic,
            "allowed_scopes": allowedScopes.map(\.rawValue).sorted().joined(separator: ",")
        ]

        let prompt = UniversalDocumentSkillService.buildPrompt(for: request)
        var draftMarkdown = ""
        var verifiedMarkdown = ""
        var verification: ResultVerificationSummary?

        for step in plan.steps {
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
                    context["draft_markdown"] = draftMarkdown
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

                verification = ResultVerifier.verifyMarkdownArtifact(
                    content: draftMarkdown,
                    requiredSections: UniversalDocumentSkillService.requiredSections(for: request.type)
                )
                if let currentVerification = verification, currentVerification.hasError {
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
                            context["draft_markdown"] = draftMarkdown
                            verification = ResultVerifier.verifyMarkdownArtifact(
                                content: draftMarkdown,
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

                guard let verification, !verification.hasError else {
                    return PlanExecutionResult(
                        status: .failed,
                        message: ResultRecoveryPolicy.failureMessage(),
                        artifactID: nil,
                        failureReason: .verificationFailed
                    )
                }

                if !verification.issues.isEmpty {
                    let warningCount = verification.issues.filter { $0.severity == .warning }.count
                    AppLog.warning("[PlanRunner] verification warnings=\(warningCount)")
                }
                verifiedMarkdown = draftMarkdown
                context["verified_markdown"] = verifiedMarkdown

            case .persistArtifact:
                await MainActor.run {
                    manager.updateRoomGoalContext(roomID: roomID, activeWorkflowStep: "planRunner.saving")
                }

                do {
                    let artifact = try await UniversalDocumentArtifactWriter.writeMarkdown(
                        content: verifiedMarkdown,
                        request: request,
                        roomID: roomID,
                        manager: manager
                    )
                    if let artifactUUID = UUID(uuidString: artifact.id) {
                        await MainActor.run {
                            manager.updateRoomGoalContext(roomID: roomID, recentArtifactID: artifactUUID)
                        }
                    }
                    context["artifact_id"] = artifact.id
                    context["artifact_filename"] = artifact.filename
                    context["artifact_title"] = artifact.title
                    context["artifact_path"] = artifact.path
                } catch {
                    return makeFailure(
                        UniversalDocumentArtifactWriter.failureMessage(error: error, request: request),
                        reason: .recoverableRuntimeError
                    )
                }
            case .report:
                guard
                    let artifactIDString = context["artifact_id"],
                    let artifactFilename = context["artifact_filename"],
                    let artifactTitle = context["artifact_title"],
                    let artifactPath = context["artifact_path"]
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
                    path: artifactPath,
                    preview: String(verifiedMarkdown.prefix(200)),
                    createdAt: ISO8601DateFormatter().string(from: Date())
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
