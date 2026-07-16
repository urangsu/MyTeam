import Foundation

enum NaturalWorkPlanRunner {
    static func run(
        _ plan: NaturalWorkPlan,
        originalText: String,
        roomID: UUID,
        manager: AgentWindowManager,
        shouldClearPending: Bool = false,
        path: ToolExecutionPath = .planner
    ) async -> Bool {
        if shouldClearPending {
            await MainActor.run {
                PendingNaturalWorkCoordinator.clear(roomID: roomID)
            }
        }

        let validatedPlan = NaturalWorkPlanValidator.planAfterValidation(plan)
        guard validatedPlan.steps.allSatisfy({ step in
            guard let descriptor = MyTeamToolRegistry.descriptor(id: step.toolID) else { return false }
            return descriptor.permissionLevel == .readOnly || descriptor.permissionLevel == .draftOnly
        }) else {
            AppLog.warning("[NaturalWorkPlanRunner] natural work blocked by permission level title=\(plan.title)")
            return false
        }

        let progressMessageID = await MainActor.run {
            ChatResponseSink.addProgress(
                roomID: roomID,
                manager: manager,
                text: NaturalWorkRouter.runningMarkdown(for: validatedPlan)
            )
        }
        let operationToken = await MainActor.run {
            manager.beginWorkflowOperation(
                status: "업무 조회 중: \(validatedPlan.title)",
                roomID: roomID
            )
        }

        let parentWorkID = UUID()
        let naturalResult = await NaturalWorkPlanExecutor.execute(
            validatedPlan,
            path: path,
            options: .composite(parentWorkID: parentWorkID)
        )
        _ = await CompositeArtifactRecorder.write(
            result: naturalResult,
            originalText: originalText,
            roomID: roomID,
            manager: manager
        )
        await MainActor.run {
            WorkContextMemory.shared.record(plan: validatedPlan, roomID: roomID)
            ChatResponseSink.updateOrAppend(
                roomID: roomID,
                manager: manager,
                messageID: progressMessageID,
                text: naturalResult.artifactMarkdown,
                agentName: "업무 실행"
            )
            manager.finishWorkflowOperation(roomID: roomID, token: operationToken)
        }
        return true
    }
}
