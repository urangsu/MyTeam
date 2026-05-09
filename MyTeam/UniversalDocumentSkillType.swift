import Foundation

enum UniversalDocumentSkillType: String, CaseIterable, Codable {
    case summary
    case reportDraft
    case checklist
    case tableSummary
    case meetingMinutes
    case actionItems

    var skillID: String {
        switch self {
        case .summary: return "korean.document-summary"
        case .reportDraft: return "korean.report-draft"
        case .checklist: return "korean.checklist"
        case .tableSummary: return "korean.table-summary"
        case .meetingMinutes: return "korean.meeting-minutes"
        case .actionItems: return "korean.action-items"
        }
    }

    var displayName: String {
        switch self {
        case .summary: return "문서 요약"
        case .reportDraft: return "보고서 초안"
        case .checklist: return "체크리스트"
        case .tableSummary: return "표 정리"
        case .meetingMinutes: return "회의록 정리"
        case .actionItems: return "액션아이템 추출"
        }
    }

    var filenameSuffix: String {
        switch self {
        case .summary: return "요약"
        case .reportDraft: return "보고서_초안"
        case .checklist: return "체크리스트"
        case .tableSummary: return "표_정리"
        case .meetingMinutes: return "회의록"
        case .actionItems: return "액션아이템"
        }
    }

    var promptTitleSuffix: String {
        switch self {
        case .summary: return "요약"
        case .reportDraft: return "보고서 초안"
        case .checklist: return "체크리스트"
        case .tableSummary: return "표 정리"
        case .meetingMinutes: return "회의록"
        case .actionItems: return "액션아이템"
        }
    }
}
