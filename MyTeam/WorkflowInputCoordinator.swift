import Foundation

struct WorkflowInputCoordinator {
    static let shared = WorkflowInputCoordinator()

    private init() {}

    func handle(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> Bool {
        let naturalSnapshot = await MainActor.run {
            let recentMessages = manager.rooms
                .first(where: { $0.id == roomID })?
                .messages
                .suffix(8)
                .filter { !$0.isSystem } ?? []
            return (context: NaturalWorkContext(
                roomID: roomID,
                activeArtifactID: nil,
                recentArtifacts: [],
                pendingAttachments: [],
                recentMessageTexts: recentMessages.map(\.text),
                lastCompanyIdentity: nil,
                lastWorkType: nil,
                userLocation: nil
            ), chatHistory: Array(recentMessages))
        }

        let pendingNaturalRequest = await MainActor.run {
            PendingNaturalWorkRequestStore.shared.pending(roomID: roomID)
        }
        if pendingNaturalRequest != nil,
           PendingNaturalWorkRequestStore.isCancellation(userMessage) {
            await MainActor.run {
                PendingNaturalWorkRequestStore.shared.clear(roomID: roomID)
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "업무 실행",
                    text: "요청을 취소했습니다.",
                    isUser: false
                )
            }
            return true
        }

        let naturalRouteText = await MainActor.run { () -> String in
            guard let pendingNaturalRequest else { return userMessage }
            return PendingNaturalWorkRequestStore.shared.mergedText(userMessage, into: pendingNaturalRequest)
        }

        switch NaturalWorkRouter.route(for: naturalRouteText, context: naturalSnapshot.context) {
        case .clarification(let request):
            await MainActor.run {
                PendingNaturalWorkRequestStore.shared.set(request, roomID: roomID)
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "업무 실행",
                    text: NaturalWorkRouter.clarificationMarkdown(for: request),
                    isUser: false
                )
            }
            return true
        case .plan(let naturalPlan):
            return await runNaturalPlan(
                naturalPlan,
                originalText: userMessage,
                roomID: roomID,
                manager: manager,
                shouldClearPending: pendingNaturalRequest != nil
            )
        case .unsupported:
            return false
        case .fallback:
            break
        }

        if let naturalPlan = await AgenticToolOrchestrator.plan(
            for: naturalRouteText,
            context: naturalSnapshot.context,
            chatHistory: naturalSnapshot.chatHistory,
            agentID: "team_all",
            agentConfig: nil
        ) {
            return await runNaturalPlan(
                naturalPlan,
                originalText: userMessage,
                roomID: roomID,
                manager: manager,
                shouldClearPending: pendingNaturalRequest != nil
            )
        }

        return await LegacyWorkflowFallbackRouter.shared.handle(
            text: naturalRouteText,
            roomID: roomID,
            manager: manager
        )
    }

    private func runNaturalPlan(
        _ naturalPlan: NaturalWorkPlan,
        originalText: String,
        roomID: UUID,
        manager: AgentWindowManager,
        shouldClearPending: Bool
    ) async -> Bool {
        if shouldClearPending {
            await MainActor.run {
                PendingNaturalWorkRequestStore.shared.clear(roomID: roomID)
            }
        }
        guard naturalPlan.steps.allSatisfy({ step in
            guard let descriptor = MyTeamToolRegistry.descriptor(id: step.toolID) else { return false }
            return descriptor.permissionLevel == .readOnly || descriptor.permissionLevel == .draftOnly
        }) else {
            AppLog.warning("[WorkflowInputCoordinator] natural work blocked by permission level title=\(naturalPlan.title)")
            return false
        }

        let progressMessageID = await MainActor.run {
            manager.addChatLog(
                roomID: roomID,
                agentID: "system",
                agentName: "업무 실행",
                text: NaturalWorkRouter.runningMarkdown(for: naturalPlan),
                isUser: false
            )
        }
        await MainActor.run {
            manager.isWorkflowRunning = true
            manager.setWorkflowStatus("업무 조회 중: \(naturalPlan.title)", for: roomID)
        }

        let naturalResult = await NaturalWorkPlanExecutor.execute(naturalPlan, path: .planner)
        _ = await CompositeWorkArtifactWriter.write(
            result: naturalResult,
            originalText: originalText
        )

        await MainActor.run {
            if let progressMessageID {
                manager.updateChatLogText(
                    roomID: roomID,
                    messageID: progressMessageID,
                    text: naturalResult.artifactMarkdown
                )
            } else {
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "업무 실행",
                    text: naturalResult.artifactMarkdown,
                    isUser: false
                )
            }
            manager.clearWorkflowStatus(for: roomID)
            manager.isWorkflowRunning = manager.activeWorkflowTaskCount() > 0
        }
        return true
    }
}

struct LegacyWorkflowFallbackRouter {
    static let shared = LegacyWorkflowFallbackRouter()

    private init() {}

    func handle(
        text: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> Bool {
        let matches = MyTeamToolFastPathRouter.matchMany(text)
        guard !matches.isEmpty else { return false }
        guard matches.allSatisfy({ $0.descriptor.permissionLevel == .readOnly || $0.descriptor.permissionLevel == .draftOnly }) else {
            AppLog.warning("[LegacyWorkflowFallbackRouter] fast-path blocked by permission level tools=\(matches.map { $0.descriptor.id }.joined(separator: ","))")
            return false
        }

        let progressText = MyTeamToolFastPathRouter.runningMarkdown(for: matches)
        let progressMessageID = await MainActor.run {
            manager.addChatLog(
                roomID: roomID,
                agentID: "system",
                agentName: "업무 실행",
                text: progressText,
                isUser: false
            )
        }
        await MainActor.run {
            manager.isWorkflowRunning = true
            let statusName = matches.count == 1 ? matches[0].descriptor.displayName : "\(matches.count)개 업무"
            manager.setWorkflowStatus("업무 도구 실행 중: \(statusName)", for: roomID)
        }

        var results: [(match: MyTeamToolFastPathMatch, state: ToolExecutionState)] = []
        for match in matches {
            let state = await ToolExecutionRouter.shared.run(
                match.descriptor,
                input: match.input,
                bypassApproval: false,
                path: .planner
            )
            results.append((match: match, state: state))
        }

        let responseText = MyTeamToolFastPathRouter.markdown(for: results)
        await MainActor.run {
            if let progressMessageID {
                manager.updateChatLogText(
                    roomID: roomID,
                    messageID: progressMessageID,
                    text: responseText
                )
            } else {
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "업무 실행",
                    text: responseText,
                    isUser: false
                )
            }
            manager.clearWorkflowStatus(for: roomID)
            manager.isWorkflowRunning = manager.activeWorkflowTaskCount() > 0
        }
        return true
    }
}
