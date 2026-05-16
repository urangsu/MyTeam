import SwiftUI

// MARK: - WorkResultKind
// Round 164A-180Z: WorkResultCardView가 문서 타입별로 다르게 보이기 위한 kind enum

enum WorkResultKind: String, Codable {
    case meetingMinutes
    case checklist
    case reportDraft
    case generic

    var title: String {
        switch self {
        case .meetingMinutes: return "회의록 초안"
        case .checklist: return "체크리스트"
        case .reportDraft: return "보고서 초안"
        case .generic: return "작업 결과"
        }
    }

    var iconName: String {
        switch self {
        case .meetingMinutes: return "doc.text"
        case .checklist: return "checkmark.circle"
        case .reportDraft: return "text.document"
        case .generic: return "sparkles"
        }
    }

    var accentColor: Color {
        switch self {
        case .meetingMinutes: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .checklist: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .reportDraft: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .generic: return Color.blue.opacity(0.7)
        }
    }

    static func detect(from skillID: String?) -> WorkResultKind {
        guard let skillID = skillID else { return .generic }
        if skillID.contains("meeting") || skillID.contains("회의록") {
            return .meetingMinutes
        }
        if skillID.contains("checklist") || skillID.contains("체크리스트") {
            return .checklist
        }
        if skillID.contains("report") || skillID.contains("보고서") {
            return .reportDraft
        }
        return .generic
    }
}
