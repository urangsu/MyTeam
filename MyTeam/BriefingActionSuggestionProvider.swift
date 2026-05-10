import Foundation

@MainActor
enum BriefingActionSuggestionProvider {
    static func makeSuggestions(
        roomID: UUID?,
        manager: AgentWindowManager,
        localItems: [LocalTaskBriefingItem]
    ) -> [BriefingActionSuggestion] {
        guard let roomID else { return [] }

        var suggestions: [BriefingActionSuggestion] = []
        let roomContext = manager.roomGoalContext(for: roomID)

        if LocalTaskBriefingActionPolicy.isSupported(.summarizeRecentFile, roomID: roomID, manager: manager) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .summarizeRecentFile,
                    title: "이 파일 요약하기",
                    prompt: "이 파일 요약해줘",
                    systemActionID: nil,
                    priority: 300
                )
            )
        }

        if LocalTaskBriefingActionPolicy.isSupported(.reuseRecentArtifact, roomID: roomID, manager: manager) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .reuseRecentArtifactAsTable,
                    title: "방금 문서 표로 바꾸기",
                    prompt: "방금 만든 문서 표로 바꿔줘",
                    systemActionID: nil,
                    priority: 290
                )
            )
        }

        if localItems.contains(where: { $0.kind == .pendingApproval }) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .approvePendingTask,
                    title: "승인 대기 확인",
                    prompt: nil,
                    systemActionID: "openSchedulePanel",
                    priority: 280
                )
            )
        }

        if localItems.contains(where: { $0.kind == .scheduledTask }) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .openSchedulePanel,
                    title: "스케줄 열기",
                    prompt: nil,
                    systemActionID: "openSchedulePanel",
                    priority: 270
                )
            )
        }

        if localItems.contains(where: { $0.kind == .pendingDelegation }) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .resumeDelegation,
                    title: "위임 작업 진행",
                    prompt: "진행해",
                    systemActionID: nil,
                    priority: 260
                )
            )
        }

        if roomContext?.currentGoal != nil {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .continueRecentGoal,
                    title: "아까 하던 거 이어서",
                    prompt: "아까 하던 거 이어서 뭐 하면 돼",
                    systemActionID: nil,
                    priority: 250
                )
            )
        }

        if localItems.contains(where: { $0.kind == .scheduledTask }) {
            suggestions.append(
                BriefingActionSuggestion(
                    id: UUID(),
                    kind: .summarizeTodayTasks,
                    title: "오늘 할 일 다시 정리",
                    prompt: "오늘 할 일 정리해줘",
                    systemActionID: nil,
                    priority: 240
                )
            )
        }

        return dedupeAndRank(suggestions)
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
        }.prefix(3).map { $0 }
    }
}
