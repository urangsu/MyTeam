import Foundation

enum LocalTaskBriefingProvider {
    @MainActor
    static func makeItems(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> [LocalTaskBriefingItem] {
        let now = Date()
        let calendar = Calendar.current
        let roomGoalContext = manager.roomGoalContext(for: roomID)
        let currentGoal = roomGoalContext?.currentGoal
        let delegationState = manager.delegationModeState(for: roomID)
        let pendingDelegatedRequest = manager.pendingDelegatedExecutionRequest(for: roomID)
        let recentRouteTraces = manager.recentRouteTraces(for: roomID)
        let recentArtifacts = recentArtifactsForRoom(roomGoalContext: roomGoalContext, manager: manager)

        var items: [LocalTaskBriefingItem] = []

        if let fileResult = manager.lastFileIntakeResult(for: roomID) {
            switch fileResult.status {
            case .ready:
                items.append(
                    LocalTaskBriefingItem(
                        id: UUID(),
                        kind: .recentFile,
                        title: "최근 파일",
                        detail: "\(fileResult.request.originalFilename)을 이어서 정리할 수 있습니다.",
                        priority: .high,
                        createdAt: now
                    )
                )
                items.append(
                    LocalTaskBriefingItem(
                        id: UUID(),
                        kind: .suggestedNextAction,
                        title: "다음 액션",
                        detail: "“이 파일 요약해줘”라고 입력하면 최근 파일을 문서로 만들 수 있습니다.",
                        priority: .normal,
                        createdAt: now
                    )
                )
            case .unsupported, .planned, .blocked, .tooLarge, .readFailed, .empty:
                items.append(
                    LocalTaskBriefingItem(
                        id: UUID(),
                        kind: .failedWorkflow,
                        title: "최근 파일 상태",
                        detail: "\(fileResult.request.originalFilename) — \(fileResult.userMessage)",
                        priority: .normal,
                        createdAt: now
                    )
                )
            }
        }

        if let artifact = recentArtifacts.first {
            let artifactName = artifact.title.isEmpty ? artifact.filename : artifact.title
            items.append(
                LocalTaskBriefingItem(
                    id: UUID(),
                    kind: .recentArtifact,
                    title: "최근 문서",
                    detail: artifactName.isEmpty ? "최근 생성 문서를 이어서 활용할 수 있습니다." : "\(artifactName)를 다시 정리할 수 있습니다.",
                    priority: .normal,
                    createdAt: now
                )
            )
            items.append(
                LocalTaskBriefingItem(
                    id: UUID(),
                    kind: .suggestedNextAction,
                    title: "다음 액션",
                    detail: "“방금 만든 문서 표로 바꿔줘”라고 입력하면 최근 문서를 다시 정리할 수 있습니다.",
                    priority: .low,
                    createdAt: now
                )
            )
        }

        let todaysAutomationTasks = manager.automationTasks
            .filter { task in
                guard task.isEnabled else { return false }
                guard task.roomID == nil || task.roomID == roomID else { return false }
                return calendar.isDate(task.nextRunAt, inSameDayAs: now)
            }
            .sorted { lhs, rhs in lhs.nextRunAt < rhs.nextRunAt }

        for task in todaysAutomationTasks.prefix(5) {
            let timeText = timeFormatter.string(from: task.nextRunAt)
            let isPendingApproval = manager.pendingApprovalTaskIDs.contains(task.id) || task.requiresApproval
            if isPendingApproval {
                items.append(
                    LocalTaskBriefingItem(
                        id: task.id,
                        kind: .pendingApproval,
                        title: "승인 대기",
                        detail: "\(timeText) \(task.title)",
                        priority: .high,
                        createdAt: task.createdAt
                    )
                )
            } else {
                items.append(
                    LocalTaskBriefingItem(
                        id: task.id,
                        kind: .scheduledTask,
                        title: task.title,
                        detail: "\(timeText) · \(task.prompt)",
                        priority: task.nextRunAt.timeIntervalSince(now) < 2 * 60 * 60 ? .high : .normal,
                        createdAt: task.createdAt
                    )
                )
            }
        }

        if let delegationState, delegationState.status == .awaitingApproval {
            items.append(
                LocalTaskBriefingItem(
                    id: delegationState.contractID ?? roomID,
                    kind: .pendingDelegation,
                    title: "위임 대기",
                    detail: delegationState.title.isEmpty ? delegationState.detail : delegationState.title,
                    priority: .high,
                    createdAt: delegationState.updatedAt
                )
            )
            items.append(
                LocalTaskBriefingItem(
                    id: UUID(),
                    kind: .suggestedNextAction,
                    title: "다음 액션",
                    detail: "“진행해”라고 입력하면 위임된 작업을 다시 이어갈 수 있습니다.",
                    priority: .normal,
                    createdAt: now
                )
            )
        } else if let pendingDelegatedRequest {
            items.append(
                LocalTaskBriefingItem(
                    id: pendingDelegatedRequest.id,
                    kind: .pendingDelegation,
                    title: "위임 대기",
                    detail: pendingDelegatedRequest.originalMessagePreview,
                    priority: .high,
                    createdAt: pendingDelegatedRequest.createdAt
                )
            )
        }

        if let failedWorkflow = recentRouteTraces.reversed().first(where: { trace in
            trace.step == .planRunnerFailed || trace.step == .blocked
        }) {
            items.append(
                LocalTaskBriefingItem(
                    id: failedWorkflow.id,
                    kind: .failedWorkflow,
                    title: "최근 실패 workflow",
                    detail: failedWorkflow.message,
                    priority: .high,
                    createdAt: failedWorkflow.timestamp
                )
            )
        }

        if let currentGoal {
            let currentGoalDetail = "“\(currentGoal.title)” 관련 작업을 이어서 확인할 수 있습니다."
            items.append(
                LocalTaskBriefingItem(
                    id: currentGoal.id,
                    kind: .suggestedNextAction,
                    title: "최근 요청",
                    detail: currentGoalDetail,
                    priority: currentGoal.requiresClarification ? .high : .normal,
                    createdAt: currentGoal.createdAt
                )
            )
        }

        if let calendarState = connectorItem(for: .googleCalendar) {
            items.append(calendarState)
        }
        if let gmailState = connectorItem(for: .gmail) {
            items.append(gmailState)
        }

        return ranked(items)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func connectorItem(for provider: AssistantConnector.Provider) -> LocalTaskBriefingItem? {
        let state = AssistantConnectorCatalog.connectionState(for: provider)
        guard state.status != .connected else { return nil }

        let priority: LocalTaskBriefingItem.Priority = {
            switch state.status {
            case .needsReauth, .error:
                return .high
            case .notConfigured, .notConnected, .comingSoon:
                return .normal
            case .connected:
                return .low
            }
        }()

        let title = provider == .googleCalendar ? "Google Calendar" : "Gmail"
        return LocalTaskBriefingItem(
            id: UUID(),
            kind: .connectorAction,
            title: title,
            detail: state.message,
            priority: priority,
            createdAt: Date()
        )
    }

    private static func recentArtifactsForRoom(
        roomGoalContext: RoomGoalContext?,
        manager: AgentWindowManager
    ) -> [IndexedArtifact] {
        let recent = manager.recentArtifacts
        guard !recent.isEmpty else { return [] }

        if let contextIDs = roomGoalContext?.recentArtifactIDs, !contextIDs.isEmpty {
            let idSet = Set(contextIDs.map(\.uuidString))
            let matched = recent.filter { idSet.contains($0.id) }
            if !matched.isEmpty {
                return matched
            }
        }

        return Array(recent.prefix(3))
    }

    private static func ranked(_ items: [LocalTaskBriefingItem]) -> [LocalTaskBriefingItem] {
        items.sorted { lhs, rhs in
            let lhsScore = priorityScore(lhs.priority)
            let rhsScore = priorityScore(rhs.priority)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private static func priorityScore(_ priority: LocalTaskBriefingItem.Priority) -> Int {
        switch priority {
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }
}
