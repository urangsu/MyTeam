import Foundation

enum DailyBriefingService {
    static func makePreviewBriefing(now: Date = Date()) -> DailyBriefing {
        let connectorStates = AssistantConnectorCatalog.connectors.map {
            AssistantConnectorCatalog.connectionState(for: $0.id)
        }

        let connectedCount = connectorStates.filter { $0.status == .connected }.count
        if connectedCount == 0 {
            return makeUnavailableBriefing(now: now)
        }

        let connectorMessages = connectorStates.map { "\($0.provider.displayName): \($0.message)" }

        return DailyBriefing(
            id: UUID(),
            date: now,
            status: .partial,
            title: "오늘 브리핑",
            summary: "연결된 계정은 있지만 실제 데이터 fetch는 아직 연결되지 않았습니다.",
            calendarItems: [],
            mailItems: [],
            taskItems: [
                DailyTaskBriefingItem(
                    id: UUID(),
                    title: "연결된 계정에서 오늘 할 일 후보를 모아보세요.",
                    dueText: nil,
                    priority: 1
                )
            ],
            attentionItems: [
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "연결된 계정 검토",
                    detail: "다음 라운드에서 실제 오늘 일정 / 새 메일 / 중요 메일 후보를 채웁니다.",
                    severity: .info
                )
            ],
            connectorMessages: connectorMessages,
            generatedAt: now
        )
    }

    static func makeUnavailableBriefing(now: Date = Date()) -> DailyBriefing {
        let connectorMessages = AssistantConnectorCatalog.connectors.map { connector in
            let state = AssistantConnectorCatalog.connectionState(for: connector.id)
            return "\(connector.displayName): \(state.message)"
        }

        return DailyBriefing(
            id: UUID(),
            date: now,
            status: .unavailable,
            title: "오늘 브리핑",
            summary: "일정과 메일 연결이 아직 준비 중입니다. 연결 후 오늘 일정, 새 메일, 확인할 항목을 한 번에 보여드립니다.",
            calendarItems: [],
            mailItems: [],
            taskItems: [],
            attentionItems: [
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "브리핑 준비 중",
                    detail: "Google Calendar는 일정 읽기부터, Gmail은 메타데이터부터 연결할 예정입니다.",
                    severity: .info
                )
            ],
            connectorMessages: connectorMessages,
            generatedAt: now
        )
    }

    @MainActor
    static func makePreviewBriefing(
        now: Date = Date(),
        calendarProvider: DailyBriefingCalendarProviding
    ) async -> DailyBriefing {
        let calendarItems = await calendarProvider.calendarItemsForToday(now: now)
        let connectorMessages = AssistantConnectorCatalog.connectors.map { connector in
            let state = AssistantConnectorCatalog.connectionState(for: connector.id)
            return "\(connector.displayName): \(state.message)"
        }

        let status: DailyBriefing.Status = calendarItems.isEmpty ? .unavailable : .partial
        let summary: String
        if calendarItems.isEmpty {
            summary = calendarProvider.statusMessage
        } else {
            summary = "오늘 일정이 연결된 계정에서 일부 준비되었습니다."
        }

        return DailyBriefing(
            id: UUID(),
            date: now,
            status: status,
            title: "오늘 브리핑",
            summary: summary,
            calendarItems: calendarItems,
            mailItems: [],
            taskItems: calendarItems.isEmpty ? [] : [
                DailyTaskBriefingItem(
                    id: UUID(),
                    title: "연결된 캘린더 일정 기반으로 오늘 우선순위를 정리하세요.",
                    dueText: nil,
                    priority: 1
                )
            ],
            attentionItems: calendarItems.isEmpty ? [
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "브리핑 준비 중",
                    detail: calendarProvider.statusMessage,
                    severity: .info
                )
            ] : [],
            connectorMessages: connectorMessages,
            generatedAt: now
        )
    }
}
