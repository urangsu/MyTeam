import Foundation

@MainActor
enum BriefingActionSuggestionProvider {
    static func makeSuggestions(
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> [BriefingActionSuggestion] {
        let localItems = LocalTaskBriefingProvider.makeItems(roomID: roomID, manager: manager)
        let roomContext = manager.roomGoalContext(for: roomID)
        let scheduleItems = actionableScheduleItems(for: roomID, manager: manager)
        let hasPendingApproval = hasPendingApprovalTask(roomID: roomID, manager: manager, localItems: localItems)
        let hasPendingDelegation = hasPendingDelegation(roomID: roomID, manager: manager, localItems: localItems)
        let hasRecentReadyFile = hasRecentReadyFile(roomID: roomID, manager: manager)
        let reusableArtifactResolution = await RecentArtifactContentResolver.resolveLatestMarkdownArtifact(
            roomID: roomID,
            manager: manager,
            allowGlobalFallback: false
        )
        let hasReusableArtifact = reusableArtifactResolution != nil
        let hasRecentGoal = roomContext?.currentGoal != nil

        var suggestions: [BriefingActionSuggestion] = []

        if hasPendingApproval {
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .showPendingApprovals,
                    title: "승인 대기 보기",
                    subtitle: "승인 대기 항목을 확인합니다.",
                    prompt: nil,
                    systemActionID: "showPendingApprovals",
                    executionMode: .systemAction,
                    priority: 500
                ),
                roomID: roomID,
                manager: manager
            )
        }

        if hasPendingDelegation {
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .resumeDelegation,
                    title: "위임 작업 진행",
                    subtitle: "위임된 작업을 다시 이어갑니다.",
                    prompt: "진행해",
                    systemActionID: nil,
                    executionMode: .promptRoute,
                    priority: 480
                ),
                roomID: roomID,
                manager: manager
            )
        }

        if let scheduleSuggestion = makeScheduleSuggestion(scheduleItems: scheduleItems) {
            append(
                &suggestions,
                scheduleSuggestion,
                roomID: roomID,
                manager: manager
            )
        }

        if !scheduleItems.isEmpty {
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .summarizeTodayTasks,
                    title: "오늘 할 일 다시 정리",
                    subtitle: "오늘 스케줄을 다시 정리합니다.",
                    prompt: "오늘 할 일 정리해줘",
                    systemActionID: nil,
                    executionMode: .promptRoute,
                    priority: 350
                ),
                roomID: roomID,
                manager: manager
            )
        }

        if hasRecentReadyFile {
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .summarizeRecentFile,
                    title: "이 파일 요약하기",
                    subtitle: "최근 파일을 다시 정리합니다.",
                    prompt: "이 파일 요약해줘",
                    systemActionID: nil,
                    executionMode: .promptRoute,
                    priority: 360
                ),
                roomID: roomID,
                manager: manager
            )
        }

        if hasReusableArtifact {
            let resolution = reusableArtifactResolution
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .reuseRecentArtifactAsTable,
                    title: "방금 문서 표로 바꾸기",
                    subtitle: "최근 문서를 표로 다시 정리합니다.",
                    prompt: "방금 만든 문서 표로 바꿔줘",
                    systemActionID: nil,
                    executionMode: .promptRoute,
                    priority: 340,
                    sourceBinding: resolution?.binding
                ),
                roomID: roomID,
                manager: manager
            )
        }

        if hasRecentGoal {
            append(
                &suggestions,
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .continueRecentGoal,
                    title: "이어서 하기",
                    subtitle: roomContext?.currentGoal?.title,
                    prompt: "아까 하던 거 이어서 뭐 하면 돼",
                    systemActionID: nil,
                    executionMode: .promptRoute,
                    priority: 280
                ),
                roomID: roomID,
                manager: manager
            )
        }

        return Array(dedupeAndRank(suggestions).prefix(3))
    }

    private static func makeScheduleSuggestion(
        scheduleItems: [AgentWindowManager.AutomationTask]
    ) -> BriefingActionSuggestion? {
        guard !scheduleItems.isEmpty else { return nil }
        let hasUpcomingWithinTwoHours = scheduleItems.contains {
            $0.nextRunAt.timeIntervalSinceNow <= 2 * 60 * 60
        }
        return BriefingActionSuggestion(
            id: UUID(),
            kind: .openSchedulePanel,
            title: "스케줄 열기",
            subtitle: hasUpcomingWithinTwoHours ? "가까운 스케줄을 확인합니다." : "오늘 일정을 확인합니다.",
            prompt: nil,
            systemActionID: "openSchedulePanel",
            executionMode: .systemAction,
            priority: hasUpcomingWithinTwoHours ? 460 : 420,
            sourceBinding: nil
        )
    }

    private static func actionableScheduleItems(
        for roomID: UUID,
        manager: AgentWindowManager
    ) -> [AgentWindowManager.AutomationTask] {
        let now = Date()
        let calendar = Calendar.current
        return manager.automationTasks
            .filter { task in
                guard task.isEnabled else { return false }
                guard task.roomID == nil || task.roomID == roomID else { return false }
                guard calendar.isDate(task.nextRunAt, inSameDayAs: now) else { return false }
                return true
            }
            .sorted { lhs, rhs in lhs.nextRunAt < rhs.nextRunAt }
    }

    private static func hasPendingApprovalTask(
        roomID: UUID,
        manager: AgentWindowManager,
        localItems: [LocalTaskBriefingItem]
    ) -> Bool {
        if localItems.contains(where: { $0.kind == .pendingApproval }) {
            return true
        }
        return ScheduledTaskApprovalResolver.hasAwaitingApproval(roomID: roomID, manager: manager)
    }

    private static func hasPendingDelegation(
        roomID: UUID,
        manager: AgentWindowManager,
        localItems: [LocalTaskBriefingItem]
    ) -> Bool {
        if localItems.contains(where: { $0.kind == .pendingDelegation }) {
            return true
        }
        if let state = manager.delegationModeState(for: roomID), state.status == .awaitingApproval {
            return true
        }
        return manager.pendingDelegatedExecutionRequest(for: roomID) != nil
    }

    private static func hasRecentReadyFile(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        guard let result = manager.lastFileIntakeResult(for: roomID) else { return false }
        return result.status == .ready
    }

    private static func append(
        _ suggestions: inout [BriefingActionSuggestion],
        _ suggestion: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager
    ) {
        guard BriefingActionIntegrityPolicy.isExecutable(suggestion, roomID: roomID, manager: manager) else {
            return
        }
        suggestions.append(suggestion)
    }

    private static func dedupeAndRank(_ suggestions: [BriefingActionSuggestion]) -> [BriefingActionSuggestion] {
        var bestByKind: [BriefingActionSuggestion.Kind: BriefingActionSuggestion] = [:]
        for suggestion in suggestions {
            if let current = bestByKind[suggestion.kind] {
                if suggestion.priority > current.priority {
                    bestByKind[suggestion.kind] = suggestion
                }
            } else {
                bestByKind[suggestion.kind] = suggestion
            }
        }

        return bestByKind.values.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title < rhs.title
            }
            return lhs.priority > rhs.priority
        }
        .prefix(3)
        .map { $0 }
    }

    static func candidateSummary(roomID: UUID, manager: AgentWindowManager) async -> (supported: Int, unsupported: Int) {
        let localItems = LocalTaskBriefingProvider.makeItems(roomID: roomID, manager: manager)
        let roomContext = manager.roomGoalContext(for: roomID)
        let scheduleItems = actionableScheduleItems(for: roomID, manager: manager)
        let reusableArtifactExists = await RecentArtifactContentResolver.resolveLatestMarkdownArtifact(
            roomID: roomID,
            manager: manager,
            allowGlobalFallback: false
        ) != nil

        let candidateSlots: [BriefingActionSuggestion?] = [
            hasPendingApprovalTask(roomID: roomID, manager: manager, localItems: localItems) ? makePendingApprovalSuggestion() : nil,
            hasPendingDelegation(roomID: roomID, manager: manager, localItems: localItems) ? makeDelegationSuggestion() : nil,
            makeScheduleSuggestion(scheduleItems: scheduleItems),
            !scheduleItems.isEmpty ? makeTodayTasksSuggestion() : nil,
            hasRecentReadyFile(roomID: roomID, manager: manager) ? makeRecentFileSuggestion() : nil,
            reusableArtifactExists ? makeReusableArtifactSuggestion(sourceBinding: nil) : nil,
            roomContext?.currentGoal != nil ? makeContinueGoalSuggestion(goalTitle: roomContext?.currentGoal?.title) : nil
        ]

        let supported = candidateSlots.compactMap { $0 }.count
        let unsupported = candidateSlots.count - supported
        return (supported, unsupported)
    }

    private static func makePendingApprovalSuggestion() -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .showPendingApprovals,
            title: "승인 대기 보기",
            subtitle: "승인 대기 항목을 확인합니다.",
            prompt: nil,
            systemActionID: "showPendingApprovals",
            executionMode: .systemAction,
            priority: 500,
            sourceBinding: nil
        )
    }

    private static func makeDelegationSuggestion() -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .resumeDelegation,
            title: "위임 작업 진행",
            subtitle: "위임된 작업을 다시 이어갑니다.",
            prompt: "진행해",
            systemActionID: nil,
            executionMode: .promptRoute,
            priority: 480,
            sourceBinding: nil
        )
    }

    private static func makeTodayTasksSuggestion() -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .summarizeTodayTasks,
            title: "오늘 할 일 다시 정리",
            subtitle: "오늘 스케줄을 다시 정리합니다.",
            prompt: "오늘 할 일 정리해줘",
            systemActionID: nil,
            executionMode: .promptRoute,
            priority: 350,
            sourceBinding: nil
        )
    }

    private static func makeRecentFileSuggestion() -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .summarizeRecentFile,
            title: "이 파일 요약하기",
            subtitle: "최근 파일을 다시 정리합니다.",
            prompt: "이 파일 요약해줘",
            systemActionID: nil,
            executionMode: .promptRoute,
            priority: 360,
            sourceBinding: nil
        )
    }

    private static func makeReusableArtifactSuggestion(sourceBinding: RecentArtifactSourceBinding?) -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .reuseRecentArtifactAsTable,
            title: "방금 문서 표로 바꾸기",
            subtitle: "최근 문서를 표로 다시 정리합니다.",
            prompt: "방금 만든 문서 표로 바꿔줘",
            systemActionID: nil,
            executionMode: .promptRoute,
            priority: 340,
            sourceBinding: sourceBinding
        )
    }

    private static func makeContinueGoalSuggestion(goalTitle: String?) -> BriefingActionSuggestion {
        BriefingActionSuggestion(
            id: UUID(),
            kind: .continueRecentGoal,
            title: "이어서 하기",
            subtitle: goalTitle,
            prompt: "아까 하던 거 이어서 뭐 하면 돼",
            systemActionID: nil,
            executionMode: .promptRoute,
            priority: 280,
            sourceBinding: nil
        )
    }
}
