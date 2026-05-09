import Foundation

struct AssistantConnector: Identifiable, Equatable {
    enum Provider: String, Codable, CaseIterable {
        case googleCalendar
        case gmail
        case naverMail
        case naverCalendar

        var displayName: String {
            switch self {
            case .googleCalendar: return "Google Calendar"
            case .gmail: return "Gmail"
            case .naverMail: return "Naver Mail"
            case .naverCalendar: return "Naver Calendar"
            }
        }
    }

    enum Capability: String, Codable, CaseIterable {
        case readCalendarEvents
        case readEmailMetadata
        case readEmailBody
        case summarizeEmail
        case createDraft
        case sendEmail
        case createCalendarEvent
        case modifyCalendarEvent
        case deleteItem

        var displayName: String {
            switch self {
            case .readCalendarEvents: return "캘린더 읽기"
            case .readEmailMetadata: return "메일 메타데이터 읽기"
            case .readEmailBody: return "메일 본문 읽기"
            case .summarizeEmail: return "메일 요약"
            case .createDraft: return "초안 작성"
            case .sendEmail: return "메일 발송"
            case .createCalendarEvent: return "일정 생성"
            case .modifyCalendarEvent: return "일정 수정"
            case .deleteItem: return "삭제"
            }
        }
    }

    let id: Provider
    let displayName: String
    let description: String
    let capabilities: [Capability]
    let isImplemented: Bool
    let notes: String
}
