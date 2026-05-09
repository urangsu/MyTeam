import Foundation

enum GoogleOAuthScope: String, CaseIterable, Codable {
    case calendarEventsReadonly = "https://www.googleapis.com/auth/calendar.events.readonly"
    case gmailMetadata = "https://www.googleapis.com/auth/gmail.metadata"
    case gmailReadonly = "https://www.googleapis.com/auth/gmail.readonly"

    var displayName: String {
        switch self {
        case .calendarEventsReadonly: return "Google Calendar 일정 읽기"
        case .gmailMetadata: return "Gmail 메타데이터 읽기"
        case .gmailReadonly: return "Gmail 본문 읽기"
        }
    }

    var priority: Int {
        switch self {
        case .calendarEventsReadonly: return 1
        case .gmailMetadata: return 2
        case .gmailReadonly: return 3
        }
    }

    var policySummary: String {
        switch self {
        case .calendarEventsReadonly:
            return "오늘 일정 브리핑용 read-only scope"
        case .gmailMetadata:
            return "새 메일 수와 제목/발신자 확인용 metadata scope"
        case .gmailReadonly:
            return "메일 본문 요약용. 추후 명시 승인 필요"
        }
    }

    var badgeLabel: String {
        switch self {
        case .calendarEventsReadonly: return "읽기 가능 예정"
        case .gmailMetadata: return "읽기 가능 예정"
        case .gmailReadonly: return "승인 필요"
        }
    }
}
