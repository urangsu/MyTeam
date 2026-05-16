import Foundation

// MARK: - DocumentCreationType
// Round 164A-180Z: 3대 기본 문서 타입
// 문서 만들기 → 회의록 / 체크리스트 / 보고서 초안

enum DocumentCreationType: String, Codable, CaseIterable {
    case meetingMinutes
    case checklist
    case reportDraft

    var title: String {
        switch self {
        case .meetingMinutes: return "회의록"
        case .checklist: return "체크리스트"
        case .reportDraft: return "보고서 초안"
        }
    }

    var description: String {
        switch self {
        case .meetingMinutes:
            return "회의 내용을 정리해 회의록 초안으로 만듭니다"
        case .checklist:
            return "업무 준비 요소를 체크리스트로 정리합니다"
        case .reportDraft:
            return "목적과 핵심 내용을 보고서 초안으로 정리합니다"
        }
    }

    var emoji: String {
        switch self {
        case .meetingMinutes: return "📋"
        case .checklist: return "✅"
        case .reportDraft: return "📄"
        }
    }

    /// Document creation을 triggering하는 문자열
    var triggerMessage: String {
        switch self {
        case .meetingMinutes: return "회의록 양식 만들어줘"
        case .checklist: return "업무 준비 체크리스트 만들어줘"
        case .reportDraft: return "보고서 초안 만들어줘"
        }
    }

    /// UniversalDocumentSkillType과의 mapping
    var skillType: UniversalDocumentSkillType {
        switch self {
        case .meetingMinutes: return .meetingMinutes
        case .checklist: return .checklist
        case .reportDraft: return .reportDraft
        }
    }
}

// MARK: - LocalDocumentTemplate
// Local fallback이 없는 상태에서 기본 템플릿 생성

enum LocalDocumentTemplate {
    static func generateMeetingMinutes() -> String {
        """
        # 회의록

        ## 회의 개요
        - 일시:
        - 참석자:
        - 주제:

        ## 논의 내용
        -

        ## 결정 사항
        -

        ## 액션 아이템

        | 담당 | 할 일 | 기한 | 상태 |
        |---|---|---|---|

        ## 다음 확인사항
        -
        """
    }

    static func generateChecklist() -> String {
        """
        # 업무 준비 체크리스트

        ## 시작 전 확인
        - [ ] 목적 확인
        - [ ] 필요한 자료 확인
        - [ ] 담당자 확인

        ## 진행 중 확인
        - [ ] 핵심 작업 정리
        - [ ] 일정 확인
        - [ ] 리스크 확인

        ## 완료 전 확인
        - [ ] 결과물 검토
        - [ ] 공유 대상 확인
        - [ ] 다음 작업 정리
        """
    }

    static func generateReportDraft() -> String {
        """
        # 보고서 초안

        ## 목적

        ## 배경

        ## 현황

        ## 검토 의견

        ## 다음 단계
        """
    }

    static func generate(for type: DocumentCreationType) -> String {
        switch type {
        case .meetingMinutes:
            return generateMeetingMinutes()
        case .checklist:
            return generateChecklist()
        case .reportDraft:
            return generateReportDraft()
        }
    }

    static func generateTitle(for type: DocumentCreationType) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        return "\(dateStr)_\(type.title)"
    }
}
