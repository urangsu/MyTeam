import Foundation

// MARK: - BeginnerTaskCard
// 초보자가 프롬프트 없이 버튼 하나로 시작할 수 있는 업무 카드 목록.
// 각 케이스는 사용자가 할 일 / 치코가 할 일로 명확히 분리된다.

enum BeginnerTaskCard: String, CaseIterable, Codable, Sendable {
    case meetingMinutes  // 회의록 만들기
    case checklist       // 체크리스트 만들기
    case reportDraft     // 보고서 초안
    case fileSummary     // 파일 읽기
    case todayPlan       // 오늘 할 일
    case tryExample      // 예시로 먼저 해보기

    var title: String {
        switch self {
        case .meetingMinutes: return "회의록 만들기"
        case .checklist:      return "체크리스트 만들기"
        case .reportDraft:    return "보고서 초안"
        case .fileSummary:    return "파일 읽기"
        case .todayPlan:      return "오늘 할 일"
        case .tryExample:     return "예시로 먼저 해보기"
        }
    }

    var subtitle: String {
        switch self {
        case .meetingMinutes:
            return "회의 내용을 붙여넣으면 정리해드려요.\n내용이 없어도 양식부터 만들 수 있어요."
        case .checklist:
            return "할 일 목록을 빠르게 만들어드려요.\n항목을 말씀해주시면 체크리스트로 정리해요."
        case .reportDraft:
            return "목적, 배경, 검토 의견 순서로 초안을 만들어요."
        case .fileSummary:
            return "txt, md, csv 파일을 읽고 요약할 수 있어요."
        case .todayPlan:
            return "지금 이어서 할 일을 정리해드려요."
        case .tryExample:
            return "샘플 회의 내용으로 회의록을 바로 만들어볼 수 있어요.\n처음이라면 여기서 시작해보세요."
        }
    }

    var iconName: String {
        switch self {
        case .meetingMinutes: return "doc.text"
        case .checklist:      return "checkmark.square"
        case .reportDraft:    return "doc.badge.plus"
        case .fileSummary:    return "folder"
        case .todayPlan:      return "calendar.badge.checkmark"
        case .tryExample:     return "play.circle.fill"
        }
    }

    /// 사용자가 직접 해야 할 일
    var userTasks: [String] {
        switch self {
        case .meetingMinutes:
            return ["회의 내용 붙여넣기 또는 파일 선택"]
        case .checklist:
            return ["할 일 목록 입력하기"]
        case .reportDraft:
            return ["보고서 목적과 배경 알려주기"]
        case .fileSummary:
            return ["파일 선택하기 (txt / md / csv)"]
        case .todayPlan:
            return ["따로 할 일 없어요 — 바로 시작해요"]
        case .tryExample:
            return ["버튼 누르기"]
        }
    }

    /// 치코(AI)가 자동으로 해주는 일
    var chikoTasks: [String] {
        switch self {
        case .meetingMinutes:
            return ["회의 목적 정리", "논의 내용 정리", "결정 사항 정리", "액션아이템 추출"]
        case .checklist:
            return ["항목 정리", "우선순위 순서 제안", "마감일 표시"]
        case .reportDraft:
            return ["목적 섹션 작성", "배경 정리", "검토 의견 초안", "다음 단계 제안"]
        case .fileSummary:
            return ["파일 내용 읽기", "핵심 요약", "표 또는 체크리스트로 변환 제안"]
        case .todayPlan:
            return ["최근 작업 이어받기", "오늘 할 일 목록 정리", "다음 액션 제안"]
        case .tryExample:
            return ["샘플 회의 내용 준비", "회의록 양식 생성", "결과 문서 저장"]
        }
    }

    /// 버튼 탭 시 dispatch할 프롬프트
    var dispatchPrompt: String {
        switch self {
        case .meetingMinutes:
            return "회의록 양식 만들어줘"
        case .checklist:
            return "체크리스트 만들어줘"
        case .reportDraft:
            return "보고서 초안 만들어줘"
        case .fileSummary:
            return "파일 읽기"
        case .todayPlan:
            return "오늘 할 일 정리해줘"
        case .tryExample:
            return BeginnerTaskCard.exampleMeetingPrompt
        }
    }

    /// 예시로 시작하기 — 샘플 회의 내용
    static let exampleMeetingPrompt: String = """
    아래 회의 내용으로 회의록 양식을 만들어줘.

    날짜: 2026-05-17
    참석자: 기획팀 3명
    주제: Q2 제품 로드맵 검토

    논의 내용:
    - Q2 출시 일정을 2주 앞당기기로 결정
    - 마케팅 콘텐츠 제작 일정 재조정 필요
    - 테스트 인력 추가 투입 검토 중

    결정 사항:
    - 출시일 5월 31일로 확정
    - 마케팅팀에 일정 공유 완료
    """

    /// 탭 0 메인 카드 (홈 화면에 바로 표시)
    static var homeCards: [BeginnerTaskCard] {
        [.meetingMinutes, .fileSummary, .reportDraft, .todayPlan]
    }
}

// MARK: - BeginnerGuidanceMessage
// 치코가 상황에 맞게 보여주는 안내 문구.
// 프롬프트 가이드, 실패 복구, 다음 액션 추천에 사용한다.

struct BeginnerGuidanceMessage: Codable, Equatable, Sendable {
    let title: String
    let body: String
    let primaryActionTitle: String
    let prompt: String?

    // MARK: - 상황별 사전 정의 메시지

    /// 앱 첫 실행 안내
    static let firstLaunch = BeginnerGuidanceMessage(
        title: "처음이신가요?",
        body: "회의록 양식부터 만들어볼까요?\n내용이 없어도 괜찮아요. 바로 쓸 수 있는 틀을 먼저 만들어드릴게요.",
        primaryActionTitle: "회의록 양식 만들기",
        prompt: "회의록 양식 만들어줘"
    )

    /// 파일 감지 안내
    static let fileDetected = BeginnerGuidanceMessage(
        title: "이 파일은 읽을 수 있어요.",
        body: "요약할까요, 표로 정리할까요, 체크리스트로 바꿀까요?",
        primaryActionTitle: "요약하기",
        prompt: "파일 요약해줘"
    )

    /// artifact 생성 완료
    static let documentCreated = BeginnerGuidanceMessage(
        title: "문서가 만들어졌어요.",
        body: "요약, 표 변환, 체크리스트로 바꿀 수 있어요.",
        primaryActionTitle: "요약하기",
        prompt: "방금 만든 문서 요약해줘"
    )

    /// 실패/오류 안내
    static let errorRecovery = BeginnerGuidanceMessage(
        title: "파일 상태가 바뀐 것 같아요.",
        body: "다시 선택해주시면 이어서 정리할 수 있어요.",
        primaryActionTitle: "파일 다시 선택",
        prompt: nil   // nil = 사용자가 파일 선택 UI를 직접 열어야 함
    )

    /// 오래 idle 상태 (치코 sleeping 후 복귀)
    static let returnFromIdle = BeginnerGuidanceMessage(
        title: "다시 돌아오셨군요.",
        body: "이어서 할 일이 있으시면 말씀해주세요.",
        primaryActionTitle: "오늘 할 일 보기",
        prompt: "오늘 할 일 정리해줘"
    )

    /// 일반 대기 상태
    static let idle = BeginnerGuidanceMessage(
        title: "오늘 무엇을 도와드릴까요?",
        body: "아래 업무 카드에서 시작하거나, 직접 입력해도 됩니다.",
        primaryActionTitle: "예시로 해보기",
        prompt: BeginnerTaskCard.exampleMeetingPrompt
    )
}

// MARK: - UserFacingTerm
// 앱 안에서 기술 용어를 사용자 친화적 언어로 변환한다.
// 개발자 문서에서는 원래 용어를 쓰고, UI 표시에는 이 enum을 사용한다.

enum UserFacingTerm {
    case artifact
    case connector
    case blocked
    case unavailable
    case route
    case skill
    case token
    case model
    case diagnostic
    case capability
    case router

    /// 사용자에게 보여줄 한국어 표현
    var displayName: String {
        switch self {
        case .artifact:    return "문서"
        case .connector:   return "연결 기능"
        case .blocked:     return "자동 실행 안 함"
        case .unavailable: return "아직 사용할 수 없음"
        case .route:       return "처리 흐름"
        case .skill:       return "기능"
        case .token:       return "사용량"
        case .model:       return "AI 엔진"
        case .diagnostic:  return "앱 상태 정보"
        case .capability:  return "할 수 있는 일"
        case .router:      return "요청 분류"
        }
    }

    /// 설명 텍스트 (툴팁 또는 안내 문구용)
    var description: String {
        switch self {
        case .artifact:
            return "처리 결과로 만들어진 파일이나 문서"
        case .connector:
            return "외부 서비스(이메일, 캘린더 등)와 연결하는 기능"
        case .blocked:
            return "안전을 위해 자동으로 실행하지 않는 작업"
        case .unavailable:
            return "현재 설정에서 사용할 수 없는 기능"
        case .route:
            return "요청을 어떤 방식으로 처리할지 결정하는 흐름"
        case .skill:
            return "특정 업무를 처리하는 내장 기능"
        case .token:
            return "AI가 처리한 텍스트 분량"
        case .model:
            return "응답을 생성하는 AI 엔진"
        case .diagnostic:
            return "앱 내부 상태 확인 정보"
        case .capability:
            return "이 설정에서 할 수 있는 작업 범위"
        case .router:
            return "요청 내용을 분석해 적합한 처리 경로를 선택하는 구성 요소"
        }
    }

    /// 에러 메시지에서 기술 용어를 사용자 친화적으로 변환한다.
    /// 예: "hash mismatch" → "파일 내용이 바뀐 것 같아요"
    static func friendlyErrorMessage(for rawMessage: String) -> String {
        let lower = rawMessage.lowercased()
        if lower.contains("hash mismatch") || lower.contains("해시 불일치") {
            return "파일 내용이 바뀐 것 같아요. 다시 선택해주시면 이어서 정리할 수 있어요."
        }
        if lower.contains("path") && (lower.contains("invalid") || lower.contains("error") || lower.contains("경로")) {
            return "파일을 열 수 없어요. 파일을 다시 선택해주세요."
        }
        if lower.contains("missing") || lower.contains("not found") || lower.contains("찾을 수 없") {
            return "파일을 찾을 수 없어요. 이동되거나 삭제된 것 같아요."
        }
        if lower.contains("metadata") || lower.contains("메타데이터") {
            return "파일 정보만 저장되어 있어요. 파일을 다시 선택하면 이어서 작업할 수 있어요."
        }
        if lower.contains("blocked") || lower.contains("차단") {
            return "이 작업은 자동으로 실행하지 않아요. 직접 확인 후 진행해주세요."
        }
        if lower.contains("unavailable") || lower.contains("사용 불가") {
            return "지금은 사용할 수 없는 기능이에요."
        }
        // 변환 규칙이 없으면 원본 반환
        return rawMessage
    }
}
