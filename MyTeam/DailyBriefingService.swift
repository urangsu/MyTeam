import Foundation

enum DailyBriefingService {
    @MainActor
    static func makePreviewBriefing(
        now: Date,
        calendarProvider: DailyBriefingCalendarProviding,
        manager: AgentWindowManager
    ) async -> DailyBriefing {
        let connectorStates = AssistantConnectorCatalog.connectors.map {
            AssistantConnectorCatalog.connectionState(for: $0.id)
        }
        let localSnapshot = DailyBriefingLocalProvider.makeSnapshot(roomID: manager.currentRoomID, manager: manager)
        let actionSuggestions = manager.currentRoomID.map {
            BriefingActionSuggestionProvider.makeSuggestions(roomID: $0, manager: manager)
        } ?? []
        let calendarItems = await calendarProvider.calendarItemsForToday(now: now)

        let connectorMessages = connectorStates.map { "\($0.provider.displayName): \($0.message)" }
        let mergedTaskItems = localSnapshot.taskItems + (calendarItems.isEmpty ? [] : [
            DailyTaskBriefingItem(
                id: UUID(),
                title: "오늘 일정 기반으로 우선순위를 다시 정리하세요.",
                dueText: nil,
                priority: 1
            )
        ])
        let mergedAttentionItems = localSnapshot.attentionItems + (calendarItems.isEmpty ? [] : [
            DailyAttentionBriefingItem(
                id: UUID(),
                title: "캘린더 연결 확인",
                detail: calendarProvider.statusMessage,
                severity: .info
            )
        ])
        let hasCalendarConnection = connectorStates.contains { $0.provider == .googleCalendar && $0.status == .connected }
        let hasAnyLocalSignal = !localSnapshot.taskItems.isEmpty || !localSnapshot.attentionItems.isEmpty
        let status: DailyBriefing.Status
        if !calendarItems.isEmpty {
            status = hasAnyLocalSignal ? .partial : .ready
        } else if hasAnyLocalSignal {
            status = .empty
        } else if hasCalendarConnection {
            status = .empty
        } else {
            status = .unavailable
        }

        return DailyBriefing(
            id: UUID(),
            date: now,
            status: status,
            title: "오늘 브리핑",
            summary: calendarItems.isEmpty ? localSnapshot.summary : "연결된 일정과 로컬 데이터를 함께 정리했습니다.",
            calendarItems: calendarItems,
            mailItems: [],
            taskItems: mergedTaskItems,
            attentionItems: mergedAttentionItems,
            connectorMessages: connectorMessages,
            localBriefingItems: localSnapshot.localBriefingItems,
            actionSuggestions: actionSuggestions,
            generatedAt: now
        )
    }

    @MainActor
    static func makeUnavailableBriefing(now: Date, manager: AgentWindowManager) -> DailyBriefing {
        let localSnapshot = DailyBriefingLocalProvider.makeSnapshot(roomID: manager.currentRoomID, manager: manager)
        let actionSuggestions = manager.currentRoomID.map {
            BriefingActionSuggestionProvider.makeSuggestions(roomID: $0, manager: manager)
        } ?? []
        let connectorMessages = AssistantConnectorCatalog.connectors.map { connector in
            let state = AssistantConnectorCatalog.connectionState(for: connector.id)
            return "\(connector.displayName): \(state.message)"
        }

        return DailyBriefing(
            id: UUID(),
            date: now,
            status: .unavailable,
            title: "오늘 브리핑",
            summary: localSnapshot.summary,
            calendarItems: [],
            mailItems: [],
            taskItems: localSnapshot.taskItems,
            attentionItems: localSnapshot.attentionItems,
            connectorMessages: connectorMessages,
            localBriefingItems: localSnapshot.localBriefingItems,
            actionSuggestions: actionSuggestions,
            generatedAt: now
        )
    }

    static func summaryText(for briefing: DailyBriefing) -> String {
        detailedSummaryText(for: briefing)
    }

    static func detailedSummaryText(for briefing: DailyBriefing) -> String {
        var lines: [String] = [
            "# 오늘 브리핑",
            "",
            "## 1. 오늘 일정"
        ]

        if briefing.calendarItems.isEmpty {
            lines.append(contentsOf: [
                "- 연결된 일정이 없습니다.",
                "- Google Calendar 연결 후 오늘 일정을 불러올 수 있습니다."
            ])
        } else {
            for item in briefing.calendarItems.prefix(3) {
                let detail = [item.timeText, item.location].compactMap { $0 }.joined(separator: " · ")
                lines.append(detail.isEmpty ? "- \(item.title)" : "- \(item.title) · \(detail)")
            }
        }

        lines.append("")
        lines.append("## 2. 새 메일")
        if briefing.mailItems.isEmpty {
            lines.append("- Gmail 메타데이터 브리핑은 준비 중입니다.")
            lines.append("- 메일 본문 요약/발송/삭제는 아직 지원하지 않습니다.")
        } else {
            for item in briefing.mailItems.prefix(3) {
                lines.append("- \(item.sender) · \(item.subject)")
            }
        }

        lines.append("")
        lines.append("## 3. 오늘 할 일")
        let todayTasks = todayTaskItems(for: briefing)
        if todayTasks.isEmpty {
            let fallbackTasks = briefing.taskItems.prefix(3)
            if fallbackTasks.isEmpty {
                lines.append("- 최근 작업 내역이나 예정된 스케줄이 없습니다.")
            } else {
                for item in fallbackTasks.prefix(3) {
                    lines.append("- \(taskLine(for: item))")
                }
            }
        } else {
            for item in todayTasks.prefix(3) {
                lines.append("- \(localTaskLine(for: item))")
            }
        }

        lines.append("")
        lines.append("## 4. 확인 필요")
        let attentionItems = localAttentionItems(for: briefing)
        if attentionItems.isEmpty {
            let fallbackAttention = briefing.attentionItems.prefix(3)
            if fallbackAttention.isEmpty {
                lines.append("- 현재 확인이 필요한 긴급 항목이 없습니다.")
            } else {
                for item in fallbackAttention.prefix(3) {
                    lines.append("- \(item.title): \(item.detail)")
                }
            }
        } else {
            for item in attentionItems.prefix(3) {
                lines.append("- \(item.title): \(item.detail)")
            }
        }

        lines.append("")
        lines.append("## 5. 다음 액션")
        let nextActions = nextActionLines(for: briefing)
        if nextActions.isEmpty {
            lines.append("- 현재 바로 실행할 수 있는 액션이 없습니다.")
        } else {
            lines.append(contentsOf: Array(nextActions.prefix(3)))
        }

        return lines.joined(separator: "\n")
    }

    private static func todayTaskItems(for briefing: DailyBriefing) -> [LocalTaskBriefingItem] {
        briefing.localBriefingItems.filter {
            switch $0.kind {
            case .scheduledTask, .recentFile, .recentArtifact, .pendingDelegation:
                return true
            case .pendingApproval, .failedWorkflow, .connectorAction, .suggestedNextAction:
                return false
            }
        }
    }

    private static func localAttentionItems(for briefing: DailyBriefing) -> [LocalTaskBriefingItem] {
        briefing.localBriefingItems.filter {
            switch $0.kind {
            case .pendingApproval, .failedWorkflow, .connectorAction:
                return true
            case .scheduledTask, .recentFile, .recentArtifact, .pendingDelegation, .suggestedNextAction:
                return false
            }
        }
    }

    private static func nextActionLines(for briefing: DailyBriefing) -> [String] {
        let suggestions = briefing.actionSuggestions.prefix(3)
        return suggestions.map { "- \($0.title)" }
    }

    private static func localTaskLine(for item: LocalTaskBriefingItem) -> String {
        switch item.kind {
        case .scheduledTask:
            if let due = item.detail.split(separator: "·", maxSplits: 1, omittingEmptySubsequences: true).first {
                let trimmed = due.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return "\(trimmed) \(item.title)"
                }
            }
            return item.title
        case .recentFile:
            return item.detail
        case .recentArtifact:
            return item.detail
        case .pendingDelegation:
            return item.detail.isEmpty ? item.title : "위임 대기: \(item.detail)"
        case .suggestedNextAction:
            return item.detail
        case .pendingApproval, .failedWorkflow, .connectorAction:
            return item.detail
        }
    }

    private static func taskLine(for item: DailyTaskBriefingItem) -> String {
        if let dueText = item.dueText, !dueText.isEmpty {
            return "\(dueText) \(item.title)"
        }
        return item.title
    }
}
