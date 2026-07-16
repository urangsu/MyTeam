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
            NaturalWorkContextProvider.snapshot(roomID: roomID, manager: manager)
        }
        let planningAgent = await MainActor.run {
            manager.fallbackTeamLeader(for: roomID)
        }
        let pendingResolution = await MainActor.run {
            PendingNaturalWorkCoordinator.resolve(
                userMessage: userMessage,
                roomID: roomID,
                manager: manager
            )
        }
        guard let naturalRouteText = pendingResolution.routeText else {
            return true
        }

        switch await NaturalWorkEntryPoint.resolve(
            text: naturalRouteText,
            context: naturalSnapshot.context,
            chatHistory: naturalSnapshot.chatHistory,
            agentID: planningAgent?.id ?? "team_all",
            agentConfig: planningAgent
        ) {
        case .clarification(let request):
            await MainActor.run {
                PendingNaturalWorkCoordinator.storeClarification(
                    request,
                    roomID: roomID,
                    manager: manager
                )
            }
            return true
        case .plan(let naturalPlan):
            return await NaturalWorkPlanRunner.run(
                naturalPlan,
                originalText: userMessage,
                roomID: roomID,
                manager: manager,
                shouldClearPending: pendingResolution.shouldClearAfterPlan
            )
        case .unsupported:
            return false
        case .fallback:
            break
        }

        return await LegacyWorkflowFallbackRouter.shared.handle(
            text: naturalRouteText,
            roomID: roomID,
            manager: manager
        )
    }
}

struct LegacyWorkflowFallbackRouter {
    static let shared = LegacyWorkflowFallbackRouter()

    private init() {}

    func handle(
        text: String,
        roomID: UUID,
        manager: AgentWindowManager,
        path: ToolExecutionPath = .planner
    ) async -> Bool {
        let matches = MyTeamToolFastPathRouter.matchMany(text)
        guard !matches.isEmpty else { return false }
        guard matches.allSatisfy({ $0.descriptor.permissionLevel == .readOnly || $0.descriptor.permissionLevel == .draftOnly }) else {
            AppLog.warning("[LegacyWorkflowFallbackRouter] fast-path blocked by permission level tools=\(matches.map { $0.descriptor.id }.joined(separator: ","))")
            return false
        }

        let progressText = MyTeamToolFastPathRouter.runningMarkdown(for: matches)
        let progressMessageID = await MainActor.run {
            ChatResponseSink.addProgress(
                roomID: roomID,
                manager: manager,
                text: progressText
            )
        }
        let operationToken = await MainActor.run {
            let statusName = matches.count == 1 ? matches[0].descriptor.displayName : "\(matches.count)개 업무"
            return manager.beginWorkflowOperation(
                status: "업무 도구 실행 중: \(statusName)",
                roomID: roomID
            )
        }

        var results: [(match: MyTeamToolFastPathMatch, state: ToolExecutionState)] = []
        for match in matches {
            let state = await ToolExecutionRouter.shared.run(
                match.descriptor,
                input: match.input,
                bypassApproval: false,
                path: path
            )
            results.append((match: match, state: state))
        }

        let responseText = MyTeamToolFastPathRouter.markdown(for: results)
        await MainActor.run {
            ChatResponseSink.updateOrAppend(
                roomID: roomID,
                manager: manager,
                messageID: progressMessageID,
                text: responseText,
                agentName: "업무 실행"
            )
            manager.finishWorkflowOperation(roomID: roomID, token: operationToken)
        }
        return true
    }
}
