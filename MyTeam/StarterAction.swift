import Foundation

// MARK: - StarterAction

struct StarterAction: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let actionType: StarterActionType
    let emoji: String

    init(
        id: String,
        title: String,
        description: String,
        actionType: StarterActionType,
        emoji: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionType = actionType
        self.emoji = emoji
    }
}

// MARK: - StarterActionType

enum StarterActionType: Equatable, Sendable {
    case userMessage(String)  // 사용자 메시지로 dispatch
    case fileIntakeOpen       // File intake 패널 열기
}

// MARK: - StarterActionProvider

enum StarterActionProvider {
    static let meetingMinutesAction = StarterAction(
        id: "starter_meeting_minutes",
        title: "회의록 양식",
        description: "바로 쓸 수 있는 회의록 초안을 만듭니다.",
        actionType: .userMessage("회의록 양식 만들어줘"),
        emoji: "📋"
    )

    static let checklistAction = StarterAction(
        id: "starter_checklist",
        title: "체크리스트",
        description: "업무 준비 요소를 체크리스트로 정리합니다.",
        actionType: .userMessage("앱 출시 체크리스트 만들어줘"),
        emoji: "✅"
    )

    static let fileIntakeAction = StarterAction(
        id: "starter_file_intake",
        title: "파일 읽기",
        description: "텍스트·마크다운·CSV 파일을 읽습니다.",
        actionType: .fileIntakeOpen,
        emoji: "📁"
    )

    static let scheduleAction = StarterAction(
        id: "starter_schedule",
        title: "오늘 할 일",
        description: "오늘 할 일과 로컬 스케줄을 봅니다.",
        actionType: .userMessage("오늘 할 일 뭐야"),
        emoji: "🗓️"
    )

    static func actions() -> [StarterAction] {
        // 모든 상태에서 4개의 starter action을 표시
        [
            meetingMinutesAction,
            checklistAction,
            fileIntakeAction,
            scheduleAction
        ]
    }

    static func actionsForFirstResult() -> [StarterAction] {
        // 첫 artifact 생성 후 표시할 액션들
        [
            StarterAction(
                id: "first_result_summary",
                title: "요약하기",
                description: "방금 만든 문서를 요약합니다.",
                actionType: .userMessage("방금 만든 문서 요약해줘"),
                emoji: "📝"
            ),
            StarterAction(
                id: "first_result_table",
                title: "표로 바꾸기",
                description: "내용을 표 형식으로 정리합니다.",
                actionType: .userMessage("방금 만든 문서 표로 바꿔줘"),
                emoji: "📊"
            ),
            StarterAction(
                id: "first_result_checklist",
                title: "체크리스트로 바꾸기",
                description: "내용을 체크리스트로 변환합니다.",
                actionType: .userMessage("방금 만든 문서 체크리스트로 바꿔줘"),
                emoji: "☑️"
            ),
            StarterAction(
                id: "first_result_open_finder",
                title: "Finder에서 보기",
                description: "파일을 Finder에서 엽니다.",
                actionType: .userMessage("Finder에서 열어줘"),
                emoji: "🔍"
            )
        ]
    }
}
