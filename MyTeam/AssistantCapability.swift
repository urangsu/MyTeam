import Foundation

enum AssistantCapability: String, Codable, CaseIterable {
    case answer
    case localSkill
    case llmGeneration
    case artifactCreation
    case dailyBriefingPreview
    case calendarRead
    case mailMetadataRead
    case mailBodyRead
    case mailSummarize
    case mailDraft
    case mailSend
    case calendarCreate
    case calendarModify
    case destructiveFileAction
    case userInitiatedOAuth
    case automaticLogin

    enum AccessTier: String, Codable {
        case available
        case future
        case requiresApproval
        case blocked
    }

    var displayName: String {
        switch self {
        case .answer: return "답변"
        case .localSkill: return "로컬 스킬"
        case .llmGeneration: return "LLM 생성"
        case .artifactCreation: return "아티팩트 생성"
        case .dailyBriefingPreview: return "오늘 브리핑"
        case .calendarRead: return "캘린더 읽기"
        case .mailMetadataRead: return "메일 메타데이터 읽기"
        case .mailBodyRead: return "메일 본문 읽기"
        case .mailSummarize: return "메일 요약"
        case .mailDraft: return "메일 초안"
        case .mailSend: return "메일 발송"
        case .calendarCreate: return "일정 생성"
        case .calendarModify: return "일정 수정"
        case .destructiveFileAction: return "파일 삭제"
        case .userInitiatedOAuth: return "사용자 시작 OAuth"
        case .automaticLogin: return "자동 로그인"
        }
    }

    var accessTier: AccessTier {
        switch self {
        case .answer, .localSkill, .llmGeneration, .artifactCreation, .dailyBriefingPreview, .userInitiatedOAuth:
            return .available
        case .calendarRead, .mailMetadataRead:
            return .future
        case .mailBodyRead, .mailSummarize, .mailDraft:
            return .requiresApproval
        case .mailSend, .calendarCreate, .calendarModify, .destructiveFileAction, .automaticLogin:
            return .blocked
        }
    }

    var policySummary: String {
        switch accessTier {
        case .available:
            return "현재 사용 가능"
        case .future:
            return "다음 단계 기능"
        case .requiresApproval:
            return "명시 승인 필요"
        case .blocked:
            return "현재 차단"
        }
    }
}
