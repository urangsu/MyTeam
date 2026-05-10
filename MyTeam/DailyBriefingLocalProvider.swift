import Foundation

struct DailyBriefingLocalSnapshot: Equatable {
    let summary: String
    let taskItems: [DailyTaskBriefingItem]
    let attentionItems: [DailyAttentionBriefingItem]
    let connectorMessages: [String]
}

enum DailyBriefingLocalProvider {
    static let isAvailable = true

    static func makeSnapshot(roomID: UUID?, manager: AgentWindowManager = .shared) -> DailyBriefingLocalSnapshot {
        let resolvedRoomID = roomID ?? manager.currentRoomID
        var taskItems: [DailyTaskBriefingItem] = []
        var attentionItems: [DailyAttentionBriefingItem] = []
        var connectorMessages: [String] = []

        if let roomID = resolvedRoomID,
           let file = manager.lastFileIntakeResult(for: roomID) {
            if file.status == .ready {
                taskItems.append(
                    DailyTaskBriefingItem(
                        id: UUID(),
                        title: "최근 파일 \(file.request.originalFilename)를 이어서 정리할 수 있습니다.",
                        dueText: nil,
                        priority: 1
                    )
                )
            } else {
                attentionItems.append(
                    DailyAttentionBriefingItem(
                        id: UUID(),
                        title: "최근 파일 상태 확인",
                        detail: "\(file.request.originalFilename) 상태: \(file.status.rawValue)",
                        severity: .info
                    )
                )
            }
        }

        if let recentArtifact = manager.recentArtifacts.first {
            taskItems.append(
                DailyTaskBriefingItem(
                    id: UUID(),
                    title: "최근 문서 \(recentArtifact.filename)를 이어서 활용할 수 있습니다.",
                    dueText: nil,
                    priority: 2
                )
            )
        }

        if let roomID = resolvedRoomID,
           let goal = manager.roomGoalContext(for: roomID)?.currentGoal {
            attentionItems.append(
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "최근 요청",
                    detail: goal.title,
                    severity: .info
                )
            )
        }

        let connectorStates = AssistantConnectorCatalog.connectors.map { connector in
            AssistantConnectorCatalog.connectionState(for: connector.id)
        }

        let googleCalendarState = connectorStates.first { $0.provider == .googleCalendar }
        let gmailState = connectorStates.first { $0.provider == .gmail }

        if let googleCalendarState {
            let message = "Google Calendar: \(googleCalendarState.message)"
            connectorMessages.append(message)
            attentionItems.append(
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "Google Calendar",
                    detail: googleCalendarState.message,
                    severity: googleCalendarState.status == .connected ? .info : .warning
                )
            )
        }

        if let gmailState {
            let message = "Gmail: \(gmailState.message)"
            connectorMessages.append(message)
            attentionItems.append(
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "Gmail",
                    detail: gmailState.message,
                    severity: .info
                )
            )
        }

        if taskItems.isEmpty && attentionItems.isEmpty {
            attentionItems.append(
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "로컬 브리핑 준비 중",
                    detail: "Google Calendar와 Gmail 연결이 아직 없어서 내부 상태만 표시합니다.",
                    severity: .info
                )
            )
        }

        let summary: String
        if taskItems.isEmpty && attentionItems.count <= 1 {
            summary = "로컬 데이터로 오늘 브리핑을 준비했습니다."
        } else {
            let countText = "최근 파일 \(taskItems.count > 0 ? "있음" : "없음"), 확인 필요 \(attentionItems.count)개"
            summary = "로컬 데이터와 연결 상태를 바탕으로 오늘 브리핑을 준비했습니다. \(countText)."
        }

        if connectorMessages.isEmpty {
            connectorMessages = AssistantConnectorCatalog.connectors.map { connector in
                let state = AssistantConnectorCatalog.connectionState(for: connector.id)
                return "\(connector.displayName): \(state.message)"
            }
        }

        return DailyBriefingLocalSnapshot(
            summary: summary,
            taskItems: taskItems,
            attentionItems: attentionItems,
            connectorMessages: connectorMessages
        )
    }
}
