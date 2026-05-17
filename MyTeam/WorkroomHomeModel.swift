import Foundation

// MARK: - WorkroomHomeModel

/// 워크룸을 UI에서 보여주기 위한 전용 projection
/// Source of truth를 복제하지 않고, 현재 room 기준 데이터만 사용
struct WorkroomHomeModel: Sendable {
    let roomID: UUID
    let title: String
    let subtitle: String
    let currentGoal: String?
    let primaryActions: [WorkroomPrimaryAction]
    let recentArtifacts: [IndexedArtifact]
    let nextActions: [WorkroomNextAction]
    let activeTaskSummary: String?

    /// roomID 기준 모델 생성
    /// - Parameters:
    ///   - roomID: 현재 워크룸 ID
    ///   - title: 워크룸 이름
    ///   - subtitle: 팀/개인 표시
    ///   - currentGoal: 현재 업무 목표 (optional)
    ///   - recentArtifacts: room-scoped only, max 3개
    nonisolated static func make(
        roomID: UUID,
        title: String,
        subtitle: String,
        currentGoal: String? = nil,
        recentArtifacts: [IndexedArtifact] = [],
        activeTaskSummary: String? = nil
    ) -> WorkroomHomeModel {
        WorkroomHomeModel(
            roomID: roomID,
            title: title,
            subtitle: subtitle,
            currentGoal: currentGoal,
            primaryActions: WorkroomPrimaryAction.allCases,
            recentArtifacts: Array(recentArtifacts.prefix(3)),
            nextActions: WorkroomNextAction.allCases,
            activeTaskSummary: activeTaskSummary
        )
    }

    /// Runtime에서 실제 room과 artifact 데이터로 모델 생성
    /// - Parameters:
    ///   - roomID: 현재 선택된 room ID
    ///   - roomTitle: room의 이름
    ///   - recentArtifacts: room-scoped recent artifacts
    nonisolated static func fromRuntime(
        roomID: UUID,
        roomTitle: String,
        recentArtifacts: [IndexedArtifact]
    ) -> WorkroomHomeModel {
        let subtitle = "팀 공간"

        return WorkroomHomeModel(
            roomID: roomID,
            title: roomTitle,
            subtitle: subtitle,
            currentGoal: nil,
            primaryActions: WorkroomPrimaryAction.allCases,
            recentArtifacts: Array(recentArtifacts.prefix(5)),
            nextActions: recentArtifacts.isEmpty ? [] : WorkroomNextAction.allCases,
            activeTaskSummary: nil
        )
    }
}
