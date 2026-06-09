import Foundation

enum GoogleOAuthScope: String, CaseIterable, Codable {
    case calendarEventsReadonly = "https://www.googleapis.com/auth/calendar.events.readonly"
    case spreadsheets = "https://www.googleapis.com/auth/spreadsheets"
    case gmailMetadata = "https://www.googleapis.com/auth/gmail.metadata"
    case gmailReadonly = "https://www.googleapis.com/auth/gmail.readonly"

    var displayName: String {
        switch self {
        case .calendarEventsReadonly: return "Google Calendar 일정 읽기"
        case .spreadsheets: return "Google Sheets 생성/수정"
        case .gmailMetadata: return "Gmail 메타데이터 읽기"
        case .gmailReadonly: return "Gmail 본문 읽기"
        }
    }

    var priority: Int {
        switch self {
        case .calendarEventsReadonly: return 1
        case .spreadsheets: return 2
        case .gmailMetadata: return 3
        case .gmailReadonly: return 4
        }
    }

    var policySummary: String {
        switch self {
        case .calendarEventsReadonly:
            return "오늘 일정 브리핑용 read-only scope"
        case .spreadsheets:
            return "Google Sheets 파일 생성/수정용. 외부 write라 명시 승인 후 사용합니다."
        case .gmailMetadata:
            return "새 메일 수와 제목/발신자 확인용 metadata scope"
        case .gmailReadonly:
            return "메일 본문 요약용. 추후 명시 승인 필요"
        }
    }

    var badgeLabel: String {
        switch self {
        case .calendarEventsReadonly: return "읽기 가능 예정"
        case .spreadsheets: return "승인 필요"
        case .gmailMetadata: return "읽기 가능 예정"
        case .gmailReadonly: return "승인 필요"
        }
    }
}
