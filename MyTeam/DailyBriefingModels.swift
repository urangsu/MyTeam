import Foundation

struct DailyBriefing: Identifiable, Equatable {
    enum Status: String, Codable {
        case unavailable
        case empty
        case ready
        case partial
        case error

        var badgeLabel: String {
            switch self {
            case .unavailable: return "연결 필요"
            case .empty: return "준비 중"
            case .ready: return "사용 가능"
            case .partial: return "일부 가능"
            case .error: return "오류"
            }
        }
    }

    let id: UUID
    let date: Date
    let status: Status
    let title: String
    let summary: String
    let calendarItems: [DailyCalendarBriefingItem]
    let mailItems: [DailyMailBriefingItem]
    let taskItems: [DailyTaskBriefingItem]
    let attentionItems: [DailyAttentionBriefingItem]
    let connectorMessages: [String]
    let localBriefingItems: [LocalTaskBriefingItem]
    let actionSuggestions: [BriefingActionSuggestion]
    let generatedAt: Date
}

struct DailyCalendarBriefingItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let timeText: String
    let location: String?
    let source: AssistantConnector.Provider?
}

struct DailyMailBriefingItem: Identifiable, Equatable {
    let id: UUID
    let sender: String
    let subject: String
    let snippet: String
    let receivedAtText: String?
    let source: AssistantConnector.Provider?
    let requiresApprovalToReadBody: Bool
}

struct DailyTaskBriefingItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let dueText: String?
    let priority: Int
}

struct DailyAttentionBriefingItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let severity: Severity

    enum Severity: String, Codable {
        case info
        case warning
        case urgent
    }
}
