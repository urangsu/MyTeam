import Foundation

// MARK: - WorkroomPrimaryAction

/// Workroom primary actions (create document, handoff file, organize today)
enum WorkroomPrimaryAction: String, CaseIterable, Codable, Sendable {
    case createDocument
    case handoffFile
    case organizeToday

    var title: String {
        switch self {
        case .createDocument:
            return "문서 만들기"
        case .handoffFile:
            return "파일 맡기기"
        case .organizeToday:
            return "오늘 정리하기"
        }
    }

    var description: String {
        switch self {
        case .createDocument:
            return "회의록, 체크리스트, 보고서 등을 만듭니다"
        case .handoffFile:
            return "파일을 AI팀에 맡겨 분석/정리합니다"
        case .organizeToday:
            return "오늘의 작업을 정리하고 정리합니다"
        }
    }

    var iconName: String {
        switch self {
        case .createDocument:
            return "doc.badge.plus"
        case .handoffFile:
            return "hand.thumbsup"
        case .organizeToday:
            return "calendar.badge.checkmark"
        }
    }

    var dispatchPrompt: String {
        switch self {
        case .createDocument:
            return "회의록 양식 만들어줘"
        case .handoffFile:
            return "파일 읽기"
        case .organizeToday:
            return "오늘 할 일 뭐야"
        }
    }
}

// MARK: - WorkroomNextAction

/// Workroom next actions (reuse recent artifact with skill actions)
enum WorkroomNextAction: String, CaseIterable, Codable, Sendable {
    case summarize
    case table
    case checklist
    case actionItems

    var title: String {
        switch self {
        case .summarize:
            return "요약하기"
        case .table:
            return "표로 바꾸기"
        case .checklist:
            return "체크리스트로 바꾸기"
        case .actionItems:
            return "액션아이템"
        }
    }

    var skillID: String {
        switch self {
        case .summarize:
            return "korean.document-summary"
        case .table:
            return "korean.table-summary"
        case .checklist:
            return "korean.checklist"
        case .actionItems:
            return "korean.action-items"
        }
    }

    var description: String {
        switch self {
        case .summarize:
            return "지금 보는 문서의 핵심을 요약합니다"
        case .table:
            return "내용을 표 형태로 정리합니다"
        case .checklist:
            return "체크리스트 형식으로 변환합니다"
        case .actionItems:
            return "액션 아이템을 추출합니다"
        }
    }

    var dispatchPrompt: String {
        switch self {
        case .summarize:
            return "방금 만든 문서 요약해줘"
        case .table:
            return "방금 만든 문서 표로 바꿔줘"
        case .checklist:
            return "방금 만든 문서 체크리스트로 바꿔줘"
        case .actionItems:
            return "방금 만든 문서 액션아이템 뽑아줘"
        }
    }
}
