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
    case prefillInput(String) // 입력칸에 넣고 사용자가 대상/내용을 보완하게 함
    case fileIntakeOpen       // File intake 패널 열기
}

// MARK: - StarterActionProvider

enum StarterActionProvider {
    static let meetingMinutesAction = StarterAction(
        id: "starter_meeting_minutes",
        title: "회의록 양식",
        description: "회의 메모를 붙여넣어 회의록으로 정리합니다.",
        actionType: .prefillInput("아래 회의 메모를 회의록으로 정리해줘.\n\n"),
        emoji: "📋"
    )

    static let checklistAction = StarterAction(
        id: "starter_checklist",
        title: "체크리스트",
        description: "주제나 항목을 받아 체크리스트로 정리합니다.",
        actionType: .prefillInput("아래 내용으로 체크리스트를 만들어줘.\n\n"),
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
                description: "요약할 내용이나 파일을 지정합니다.",
                actionType: .prefillInput("요약할 내용이나 파일을 지정해서 요약해줘.\n\n"),
                emoji: "📝"
            ),
            StarterAction(
                id: "first_result_table",
                title: "표로 바꾸기",
                description: "표로 바꿀 내용이나 파일을 지정합니다.",
                actionType: .prefillInput("표로 바꿀 내용이나 파일을 지정해서 정리해줘.\n\n"),
                emoji: "📊"
            ),
            StarterAction(
                id: "first_result_checklist",
                title: "체크리스트로 바꾸기",
                description: "체크리스트로 바꿀 내용을 지정합니다.",
                actionType: .prefillInput("체크리스트로 바꿀 내용이나 파일을 지정해서 정리해줘.\n\n"),
                emoji: "☑️"
            ),
            StarterAction(
                id: "first_result_open_finder",
                title: "Finder에서 보기",
                description: "열 파일이나 결과물을 지정합니다.",
                actionType: .prefillInput("Finder에서 열 파일이나 결과물을 지정해줘.\n\n"),
                emoji: "🔍"
            )
        ]
    }
}
