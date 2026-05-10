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
            lines.append("- 메일 브리핑은 아직 준비 중입니다.")
            lines.append("- 메일 발송/삭제는 현재 차단되어 있습니다.")
        } else {
            for item in briefing.mailItems.prefix(3) {
                lines.append("- \(item.sender) · \(item.subject)")
            }
        }

        lines.append("")
        lines.append("## 3. 오늘 할 일")
        if briefing.taskItems.isEmpty {
            lines.append("- 최근 파일이나 문서에서 이어서 할 작업이 없습니다.")
        } else {
            for item in briefing.taskItems.prefix(3) {
                lines.append("- \(item.title)")
            }
        }

        lines.append("")
        lines.append("## 4. 확인 필요")
        if briefing.attentionItems.isEmpty {
            lines.append("- 확인 필요 항목이 없습니다.")
        } else {
            for item in briefing.attentionItems.prefix(3) {
                lines.append("- \(item.title)")
            }
        }

        lines.append("")
        lines.append("## 5. 다음 액션")
        var nextActions: [String] = []
        if let firstTask = briefing.taskItems.first {
            nextActions.append("- \(firstTask.title)")
        }
        if briefing.calendarItems.isEmpty {
            nextActions.append("- Google Calendar 연결 후 오늘 일정을 더 정확히 불러올 수 있습니다.")
        }
        if briefing.mailItems.isEmpty {
            nextActions.append("- 메일 브리핑은 아직 준비 중입니다.")
        }
        if nextActions.isEmpty {
            nextActions.append("- \"이 파일 요약해줘\"처럼 이어서 요청할 수 있습니다.")
        }
        lines.append(contentsOf: Array(nextActions.prefix(2)))

        return lines.joined(separator: "\n")
    }
}
