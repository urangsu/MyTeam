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
            generatedAt: now
        )
    }

    @MainActor
    static func makeUnavailableBriefing(now: Date, manager: AgentWindowManager) -> DailyBriefing {
        let localSnapshot = DailyBriefingLocalProvider.makeSnapshot(roomID: manager.currentRoomID, manager: manager)
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
            generatedAt: now
        )
    }

    static func summaryText(for briefing: DailyBriefing) -> String {
        let calendarCount = briefing.calendarItems.count
        let mailCount = briefing.mailItems.count
        let taskCount = briefing.taskItems.count
        let attentionCount = briefing.attentionItems.count
        return "오늘 일정 \(calendarCount)개, 새 메일 \(mailCount)개, 오늘 할 일 \(taskCount)개, 확인 필요 \(attentionCount)개"
    }
}
