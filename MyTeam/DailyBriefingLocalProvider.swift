import Foundation

struct DailyBriefingLocalSnapshot: Equatable {
    let summary: String
    let taskItems: [DailyTaskBriefingItem]
    let attentionItems: [DailyAttentionBriefingItem]
    let connectorMessages: [String]
    let localBriefingItems: [LocalTaskBriefingItem]
    let localTaskActionCount: Int
    let localTaskSuggestedActionCount: Int
    let localTaskUnsupportedActionCount: Int
    let recentArtifactContentResolverAvailable: Bool
    let recentArtifactReusableCount: Int
}

enum DailyBriefingLocalProvider {
    static let isAvailable = true

    @MainActor
    static func makeSnapshot(roomID: UUID?, manager: AgentWindowManager? = nil) -> DailyBriefingLocalSnapshot {
        let manager = manager ?? .shared
        let resolvedRoomID = roomID ?? manager.currentRoomID
        let localItems = resolvedRoomID.map { LocalTaskBriefingProvider.makeItems(roomID: $0, manager: manager) } ?? []
        let connectorMessages = AssistantConnectorCatalog.connectors.map { connector in
            let state = AssistantConnectorCatalog.connectionState(for: connector.id)
            return "\(state.provider.displayName): \(state.message)"
        }
        let localTaskActionCandidates = [
            LocalTaskBriefingAction.summarizeRecentFile,
            .reuseRecentArtifact,
            .summarizeTodayTasks,
            .resumeDelegation,
            .askContinuation
        ]
        let localTaskActionCount = localTaskActionCandidates.filter {
            LocalTaskBriefingActionPolicy.isSupported($0, roomID: resolvedRoomID, manager: manager)
        }.count
        let localTaskSuggestedActionCount = localItems.filter { $0.kind == .suggestedNextAction }.count
        let localTaskUnsupportedActionCount = localTaskActionCandidates.count - localTaskActionCount
        let recentArtifactReusableCount = resolvedRoomID.map {
            RecentArtifactContentResolver.countReusableArtifacts(roomID: $0, manager: manager)
        } ?? 0
        let recentArtifactContentResolverAvailable = resolvedRoomID.map {
            LocalTaskBriefingActionPolicy.isSupported(.reuseRecentArtifact, roomID: $0, manager: manager)
        } ?? false

        var taskItems: [DailyTaskBriefingItem] = []
        var attentionItems: [DailyAttentionBriefingItem] = []

        for item in localItems {
            switch item.kind {
            case .scheduledTask, .recentFile, .recentArtifact, .pendingDelegation:
                taskItems.append(
                    DailyTaskBriefingItem(
                        id: item.id,
                        title: item.title,
                        dueText: item.detail,
                        priority: priorityRank(item.priority)
                    )
                )
            case .pendingApproval, .failedWorkflow, .connectorAction:
                attentionItems.append(
                    DailyAttentionBriefingItem(
                        id: item.id,
                        title: item.title,
                        detail: item.detail,
                        severity: severity(for: item.priority)
                    )
                )
            case .suggestedNextAction:
                break
            }
        }

        if taskItems.isEmpty && attentionItems.isEmpty {
            attentionItems.append(
                DailyAttentionBriefingItem(
                    id: UUID(),
                    title: "로컬 브리핑 준비 중",
                    detail: "최근 작업 내역이나 연결된 계정이 없어 기본 상태만 표시합니다.",
                    severity: .info
                )
            )
        }

        let summary: String = {
            if taskItems.isEmpty && attentionItems.count <= 1 {
                return "로컬 데이터로 오늘 브리핑을 준비했습니다."
            }
            let countText = "할 일 \(taskItems.count)개, 확인 필요 \(attentionItems.count)개"
            return "로컬 작업 내역과 연결 상태를 바탕으로 오늘 브리핑을 준비했습니다. \(countText)."
        }()

        return DailyBriefingLocalSnapshot(
            summary: summary,
            taskItems: taskItems,
            attentionItems: attentionItems,
            connectorMessages: connectorMessages,
            localBriefingItems: localItems,
            localTaskActionCount: localTaskActionCount,
            localTaskSuggestedActionCount: localTaskSuggestedActionCount,
            localTaskUnsupportedActionCount: localTaskUnsupportedActionCount,
            recentArtifactContentResolverAvailable: recentArtifactContentResolverAvailable,
            recentArtifactReusableCount: recentArtifactReusableCount
        )
    }

    private static func priorityRank(_ priority: LocalTaskBriefingItem.Priority) -> Int {
        switch priority {
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }

    private static func severity(for priority: LocalTaskBriefingItem.Priority) -> DailyAttentionBriefingItem.Severity {
        switch priority {
        case .high: return .urgent
        case .normal: return .warning
        case .low: return .info
        }
    }
}
