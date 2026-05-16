import Foundation

// MARK: - WorkroomHomeModel

/// 워크룸을 UI에서 보여주기 위한 전용 projection
/// Source of truth를 복제하지 않고, 현재 room 기준 데이터만 사용
struct WorkroomHomeModel: Equatable, Sendable {
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

// MARK: - WorkroomPrimaryAction

enum WorkroomPrimaryAction: String, CaseIterable, Codable, Sendable {
    case createDocument
    case handoffFile
    case organizeToday

    var title: String {
        switch self {
        case .createDocument: return "문서 만들기"
        case .handoffFile: return "파일 맡기기"
        case .organizeToday: return "오늘 정리하기"
        }
    }

    var description: String {
        switch self {
        case .createDocument: return "회의록, 체크리스트, 보고서 등을 만듭니다"
        case .handoffFile: return "파일을 AI팀에 맡겨 분석/정리합니다"
        case .organizeToday: return "오늘의 작업을 정리하고 정리합니다"
        }
    }

    var iconName: String {
        switch self {
        case .createDocument: return "doc.badge.plus"
        case .handoffFile: return "hand.thumbsup"
        case .organizeToday: return "calendar.badge.checkmark"
        }
    }
}

// MARK: - WorkroomNextAction

enum WorkroomNextAction: String, CaseIterable, Codable, Sendable {
    case summarize
    case table
    case checklist
    case actionItems

    var title: String {
        switch self {
        case .summarize: return "요약하기"
        case .table: return "표로 바꾸기"
        case .checklist: return "체크리스트로 바꾸기"
        case .actionItems: return "액션아이템"
        }
    }

    var skillID: String {
        switch self {
        case .summarize: return "korean.document-summary"
        case .table: return "korean.table-summary"
        case .checklist: return "korean.checklist"
        case .actionItems: return "korean.action-items"
        }
    }

    var description: String {
        switch self {
        case .summarize: return "지금 보는 문서의 핵심을 요약합니다"
        case .table: return "내용을 표 형태로 정리합니다"
        case .checklist: return "체크리스트 형식으로 변환합니다"
        case .actionItems: return "액션 아이템을 추출합니다"
        }
    }
}
