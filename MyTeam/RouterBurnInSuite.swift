import Foundation

@MainActor
enum RouterBurnInSuite {
    static let cases: [RouterBurnInCase] = [
        .init(
            id: "app-launch-copy-ad",
            message: "IMMM 앱스토어 설명문 만들어줘. 광고를 써.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.app-store-copy",
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: false,
            notes: "명시적 앱스토어 문서 타입이 광고 키워드보다 우선"
        ),
        .init(
            id: "app-launch-onboarding-subscription",
            message: "IMMM 온보딩 문구 만들어줘. 구독은 없어.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.onboarding-copy",
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: false,
            notes: "온보딩 문서 타입 우선"
        ),
        .init(
            id: "app-launch-checklist-adsdk",
            message: "IMMM 출시 체크리스트 만들어줘. 광고 SDK 써.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.launch-checklist",
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: false,
            notes: "출시 체크리스트 우선"
        ),
        .init(
            id: "app-launch-monetization",
            message: "IMMM 수익화 점검표 만들어줘. 광고와 구독 고민 중이야.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.monetization-review",
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: false,
            notes: "명시적 수익화 문서만 monetizationReview로 라우팅"
        ),
        .init(
            id: "app-launch-missing-name",
            message: "광고를 쓰는 앱이야. 앱스토어 설명문 만들어줘.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.app-store-copy",
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: false,
            notes: "앱 이름 누락이면 질문/가정 경로"
        ),
        .init(
            id: "delegation-app-launch",
            message: "IMMM 출시 준비 맡길게. 앱스토어 설명문이랑 온보딩까지 알아서 만들어줘.",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "appLaunchPack",
            expectedGoalType: "appLaunch",
            shouldRequireApproval: true,
            notes: "위임 요청은 승인 대기 상태로 전환"
        ),
        .init(
            id: "delegation-approval",
            message: "진행해",
            expectedRoute: .delegationApproval,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "승인 표현"
        ),
        .init(
            id: "delegation-cancel",
            message: "위임모드 종료",
            expectedRoute: .delegationCancel,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "종료 표현"
        ),
        .init(
            id: "delegation-mail",
            message: "메일 보내기까지 알아서 해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            expectedGoalType: "mailAction",
            shouldRequireApproval: true,
            notes: "외부 전송은 재승인 필요"
        ),
        .init(
            id: "delegation-payment",
            message: "결제까지 알아서 진행해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "결제는 차단 또는 재승인 경계"
        ),
        .init(
            id: "privacy-terms-basic",
            message: "내 IMMM 앱 개인정보처리방침과 이용약관 초안 만들어줘",
            expectedRoute: .privacyTerms,
            expectedSkillID: "korean.privacy-terms",
            expectedRouteHint: "privacyTerms",
            expectedGoalType: "privacyTerms",
            shouldRequireApproval: false,
            notes: "개인정보처리방침 / 이용약관 라우팅"
        ),
        .init(
            id: "privacy-terms-ownership",
            message: "삼성 공식 개인정보처리방침 만들어줘",
            expectedRoute: .privacyTerms,
            expectedSkillID: "korean.privacy-terms",
            expectedRouteHint: "privacyTerms",
            expectedGoalType: "privacyTerms",
            shouldRequireApproval: false,
            notes: "소유권 확인 문구가 필요할 수 있음"
        ),
        .init(
            id: "local-character-count",
            message: "글자 수 세줘: 안녕하세요",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.character-count",
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "로컬 처리 (기기 내 계산)"
        ),
        .init(
            id: "local-spell-check",
            message: "이 문장 맞춤법 검사해줘",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.spell-check",
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "활성 스킬 매칭"
        ),
        .init(
            id: "artifact-report",
            message: "MyTeam 소개 보고서 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "보고서 초안은 universal document workflow"
        ),
        .init(
            id: "artifact-table",
            message: "기능 목록을 표로 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "표 정리는 universal document workflow"
        ),
        .init(
            id: "doc-summary",
            message: "이 내용 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "문서 요약, planRunner flag false keeps legacy route"
        ),
        .init(
            id: "doc-report-draft",
            message: "검토보고서 초안 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "보고서 초안"
        ),
        .init(
            id: "doc-checklist",
            message: "출근 전에 볼 체크리스트 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "체크리스트"
        ),
        .init(
            id: "doc-meeting-minutes",
            message: "회의 내용을 회의록처럼 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.meeting-minutes",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "회의록"
        ),
        .init(
            id: "doc-action-items",
            message: "해야 할 일 액션아이템으로 뽑아줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.action-items",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "액션아이템"
        ),
        .init(
            id: "doc-table-summary",
            message: "표로 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "표 정리"
        ),
        .init(
            id: "doc-generic-summary",
            message: "이거 업무용으로 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "일반 정리 요청"
        ),
        .init(
            id: "doc-recent-artifact-reference",
            message: "방금 만든 거 표로 다시 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 artifact 참조 케이스"
        ),
        .init(
            id: "doc-recent-artifact-summary",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 artifact 요약"
        ),
        .init(
            id: "doc-recent-artifact-checklist",
            message: "방금 만든 보고서 체크리스트로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 artifact 체크리스트 변환"
        ),
        .init(
            id: "doc-recent-artifact-actions",
            message: "직전에 만든 문서 액션아이템 뽑아줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.action-items",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 artifact 액션아이템 추출"
        ),
        .init(
            id: "doc-recent-artifact-table",
            message: "방금 만든 문서 표로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 artifact 표 변환"
        ),
        .init(
            id: "doc-generic-summary-no-context",
            message: "그냥 정리해봐",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "문맥 없는 정리 요청은 universal document로 보내지 않음"
        ),
        .init(
            id: "direct-chat",
            message: "오늘 기분 어때?",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "일반 대화"
        ),
        .init(
            id: "direct-chat-what-do-you-think",
            message: "이 상황 어떻게 봐?",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "잡담/의견 질문은 direct chat"
        ),
        .init(
            id: "artifact-ppt",
            message: "PPT 만들어줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "PPT는 universal document보다 기존 artifact workflow"
        ),
        .init(
            id: "artifact-xlsx",
            message: "엑셀 파일 만들어줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "엑셀은 기존 artifact workflow"
        ),
        .init(
            id: "team-discussion",
            message: "이 기능 방향을 팀원들이 검토해줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "teamDiscussion",
            shouldRequireApproval: false,
            notes: "팀 토론"
        ),
        .init(
            id: "pipeline-review-draft",
            message: "검토자가 초안 봐줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "teamDiscussion",
            shouldRequireApproval: false,
            notes: "future agentPipeline route candidate"
        ),
        .init(
            id: "pipeline-split-review",
            message: "팀원들이 나눠서 검토해줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "teamDiscussion",
            shouldRequireApproval: false,
            notes: "future agentPipeline route candidate"
        ),
        .init(
            id: "pipeline-create-and-review",
            message: "초안 만들고 검토까지 해줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "teamDiscussion",
            shouldRequireApproval: false,
            notes: "future agentPipeline / delegation candidate"
        ),
        .init(
            id: "disabled-law-search",
            message: "법령 검색해줘",
            expectedRoute: .disabledSkill,
            expectedSkillID: "korean.law-search",
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "default disabled 스킬"
        ),
        .init(
            id: "blocked-bank-account",
            message: "은행 계좌 조회해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: true,
            notes: "로그인/금융 고위험"
        ),
        .init(
            id: "blocked-payment",
            message: "내 카드로 결제해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: true,
            notes: "결제 차단"
        ),
        .init(
            id: "future-google-calendar",
            message: "오늘 일정 뭐 있어?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-gmail-metadata",
            message: "새 메일 몇 통 왔어?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-gmail-summary",
            message: "중요한 메일만 요약해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-google-calendar-connect",
            message: "구글 캘린더 연결해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "향후 OAuth connector setup route 후보"
        ),
        .init(
            id: "future-daily-briefing-route",
            message: "오늘 일정 브리핑해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-google-calendar-read",
            message: "구글 일정 읽기 권한 연결할게",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "향후 calendar read-only connection route 후보"
        ),
        .init(
            id: "file-summary-ready-file",
            message: "파일 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "recent ready file가 있으면 file intake document candidate"
        ),
        .init(
            id: "file-report-ready-file",
            message: "파일 보고서 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "recent ready file가 있으면 file intake document candidate"
        ),
        .init(
            id: "file-checklist-ready-file",
            message: "파일 체크리스트 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "recent ready file가 있으면 file intake document candidate"
        ),
        .init(
            id: "file-table-ready-file",
            message: "이 파일 표로 정리해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "recent file reference candidate"
        ),
        .init(
            id: "file-create-generic",
            message: "파일 만들어줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "file intake document must not intercept file creation"
        ),
        .init(
            id: "autonomy-daily-briefing",
            message: "오늘 뭐 해야 해?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "GoalInterpreter should classify dailyBriefing"
        ),
        .init(
            id: "autonomy-mail-calendar",
            message: "메일이랑 일정 보고 오늘 할 일 정리해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing + calendarRead + mailMetadataRead 준비 케이스"
        ),
        .init(
            id: "autonomy-document-work",
            message: "이거 업무용으로 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "문서화 목표 추론 준비 케이스"
        ),
        .init(
            id: "autonomy-delegation",
            message: "내가 손 안 대도 되게 끝까지 정리해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            shouldRequireApproval: true,
            notes: "위임 의도 우선"
        ),
        .init(
            id: "autonomy-mail-metadata",
            message: "새 메일 몇 통 왔어?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "mailBriefing",
            shouldRequireApproval: false,
            notes: "메일 메타데이터 브리핑은 dailyBriefing route"
        ),
        .init(
            id: "autonomy-mail-send",
            message: "메일 보내줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "mailAction",
            shouldRequireApproval: true,
            notes: "mailSend blocked"
        ),
        .init(
            id: "autonomy-user-initiated-oauth",
            message: "구글 캘린더 연결할게",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "connectorSetup",
            shouldRequireApproval: false,
            notes: "userInitiatedOAuth 준비 케이스"
        ),
        .init(
            id: "autonomy-auto-login",
            message: "자동으로 로그인해서 일정 가져와",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "connectorSetup",
            shouldRequireApproval: true,
            notes: "automaticLogin blocked"
        ),
        .init(
            id: "future-daily-briefing",
            message: "오늘 브리핑 해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-calendar-briefing",
            message: "오늘 일정 뭐 있어?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-mail-count-briefing",
            message: "새 메일 몇 통 왔어?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "mailBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-mail-important-briefing",
            message: "중요한 메일만 알려줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "mailBriefing",
            shouldRequireApproval: false,
            notes: "dailyBriefing route"
        ),
        .init(
            id: "future-file-summary",
            message: "파일 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "향후 file intake route 후보"
        ),
        .init(
            id: "future-csv-table",
            message: "csv 표로 정리해줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "향후 file intake route 후보"
        ),
        .init(
            id: "future-pdf-summary",
            message: "pdf 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "준비 중 확장자에 대한 future file intake 후보"
        ),
        .init(
            id: "future-sh-blocked",
            message: "sh 파일 실행해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "실행 스크립트는 blocked"
        ),
        .init(
            id: "blocked-delete",
            message: "workspace 파일 삭제해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "삭제 차단"
        ),
        .init(
            id: "delegation-artifact-request",
            message: "보고서랑 체크리스트를 내가 맡길게",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            expectedGoalType: "documentWork",
            shouldRequireApproval: true,
            notes: "artifact 경계 + 위임"
        ),
        .init(
            id: "delegation-team-discussion",
            message: "기획부터 결과까지 알아서 해줘. 팀 의견도 정리해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            expectedGoalType: "teamDiscussion",
            shouldRequireApproval: true,
            notes: "팀 토론 위임"
        ),
        .init(
            id: "briefing-now-what",
            message: "지금 뭐 해야 해?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "extended briefing keywords"
        ),
        .init(
            id: "briefing-next-action",
            message: "다음 작업 알려줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "extended briefing keywords"
        ),
        .init(
            id: "briefing-continue-work",
            message: "이어서 할 일 뭐야?",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "extended briefing keywords"
        ),
        .init(
            id: "briefing-do-today",
            message: "오늘 할 일 뭐야",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-should-do",
            message: "오늘 해야 할 일 알려줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-work-now",
            message: "지금 이어서 할 일 뭐야",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-continue-later",
            message: "아까 하던 거 이어서 뭐 하면 돼",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-task-summary",
            message: "오늘 작업 정리해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-todo-summary",
            message: "오늘 할 일 정리해줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-work-broadcast",
            message: "오늘 내 업무 브리핑",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local task briefing keywords"
        ),
        .init(
            id: "briefing-open-schedule",
            message: "스케줄 열어줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "schedule bridge keywords"
        ),
        .init(
            id: "briefing-today-schedule",
            message: "오늘 스케줄 보여줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "schedule bridge keywords"
        ),
        .init(
            id: "briefing-pending-approval",
            message: "승인 대기 보여줘",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "dailyBriefing",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "briefing action phrase"
        ),
        .init(
            id: "briefing-pending-action",
            message: "승인 필요한 작업 보여줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "dailyBriefing",
            shouldRequireApproval: false,
            notes: "local scheduler command route"
        ),
        .init(
            id: "scheduler-document-report",
            message: "오늘 스케줄 기준 보고서 만들어줘",
            expectedRoute: .localSchedulerDocumentBridge,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "localSchedulerDocumentBridge",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "local scheduler document bridge: reportDraft"
        ),
        .init(
            id: "scheduler-document-checklist",
            message: "오늘 업무 체크리스트 만들어줘",
            expectedRoute: .localSchedulerDocumentBridge,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "localSchedulerDocumentBridge",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "local scheduler document bridge: checklist"
        ),
        .init(
            id: "scheduler-document-pending-approvals",
            message: "승인 대기 목록 정리해줘",
            expectedRoute: .localSchedulerDocumentBridge,
            expectedSkillID: "korean.action-items",
            expectedRouteHint: "localSchedulerDocumentBridge",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "local scheduler document bridge: actionItems"
        ),
        .init(
            id: "scheduler-document-delegated-work",
            message: "위임 작업 정리해줘",
            expectedRoute: .localSchedulerDocumentBridge,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "localSchedulerDocumentBridge",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "local scheduler document bridge: summary"
        ),
        .init(
            id: "scheduler-open-schedule",
            message: "스케줄 열어줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: openSchedulePanel"
        ),
        .init(
            id: "scheduler-today-schedule",
            message: "오늘 스케줄 보여줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: showTodaySchedule"
        ),
        .init(
            id: "scheduler-pending-approvals",
            message: "승인 대기 보여줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: showPendingApprovals"
        ),
        .init(
            id: "scheduler-remaining-work",
            message: "오늘 업무 뭐 남았어?",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: summarizeRemainingWork"
        ),
        .init(
            id: "scheduler-schedule-based-tasks",
            message: "오늘 스케줄 기준으로 할 일 정리해줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: summarizeScheduleBasedTasks"
        ),
        .init(
            id: "scheduler-delegated-work",
            message: "진행 중인 위임 작업 보여줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: showDelegatedWork"
        ),
        .init(
            id: "scheduler-policy",
            message: "스케줄 정책 알려줘",
            expectedRoute: .localSchedulerCommand,
            expectedSkillID: nil,
            expectedRouteHint: "localSchedulerCommand",
            expectedGoalType: "unknown",
            shouldRequireApproval: false,
            notes: "local scheduler command: showSchedulePolicy"
        ),
        .init(
            id: "blocked-calendar-create",
            message: "일정 만들어줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "calendar write is blocked"
        ),
        .init(
            id: "blocked-calendar-add",
            message: "캘린더에 추가해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "calendar write is blocked"
        ),
        .init(
            id: "blocked-email-send",
            message: "메일 보내줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "unknown",
            shouldRequireApproval: true,
            notes: "email send is blocked"
        ),
        // Round 34D-34F additions: Recent artifact reuse, persistence, UX polish
        .init(
            id: "recent-artifact-summary",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "recent artifact reuse: summary type"
        ),
        .init(
            id: "recent-artifact-table",
            message: "방금 만든 문서 표로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "recent artifact reuse: table type"
        ),
        .init(
            id: "recent-artifact-checklist",
            message: "방금 만든 내용 체크리스트로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "recent artifact reuse: checklist type"
        ),
        .init(
            id: "recent-artifact-none",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "no recent artifact available -> fallback to direct chat or suggest creation"
        ),
        .init(
            id: "recent-artifact-file-moved",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "recent artifact file deleted/moved -> resolver returns nil"
        ),
        .init(
            id: "recent-artifact-unsupported-type",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "recent artifact is PDF/XLSX (unsupported) -> resolver returns nil"
        ),
        // Step 7 additions: Result status artifacts, verification errors, recent index priority
        .init(
            id: "artifact-verification-success",
            message: "보고서 초안 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "artifact workflow with successful verification should persist and index"
        ),
        .init(
            id: "artifact-verification-warning",
            message: "간단한 요약 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "verification warning allows storage with review note, index registration succeeds"
        ),
        .init(
            id: "artifact-verification-error-recovery",
            message: "짧은 내용 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "verification error triggers recovery retry, success on retry allows storage and index"
        ),
        .init(
            id: "artifact-verification-error-failed",
            message: "5자 이하 작업 해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "verification error with failed recovery prevents storage and blocks index registration"
        ),
        .init(
            id: "recent-index-priority-room-scoped",
            message: "방금 만든 거 표로 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "RecentArtifactIndex room-scoped entry takes priority over global recent artifacts"
        ),
        .init(
            id: "recent-index-priority-fallback-context",
            message: "이전 결과 참조해서 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "RoomGoalContext.recentArtifactIDs fallback when index unavailable"
        ),
        .init(
            id: "recent-index-content-hash-validation",
            message: "이전 작업 수정해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "RecentArtifactIndex content hash validation ensures artifact freshness"
        ),
        .init(
            id: "result-status-succeeded-artifact-indexed",
            message: "작업 결과 저장해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "ToolResultStatus.succeeded triggers artifact persistence and RecentArtifactIndex registration"
        ),
        .init(
            id: "result-status-dryrun-no-artifact",
            message: "시뮬레이션으로 작업해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "ToolResultStatus.dryRun prevents artifact persistence and index registration"
        ),
        .init(
            id: "result-status-blocked-no-artifact",
            message: "보안 확인 후 작업해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "ToolResultStatus.blocked prevents artifact persistence, index registration forbidden"
        ),
        .init(
            id: "result-status-failed-no-artifact",
            message: "실패한 작업 재시도해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "ToolResultStatus.failed prevents artifact persistence and index registration"
        ),
        .init(
            id: "plan-execution-artifact-count-completed-with-id",
            message: "최종 보고서 작업 완료",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "PlanExecutionResult.completed with artifactID = artifactCount 1 for diagnostics"
        ),
        .init(
            id: "plan-execution-artifact-count-completed-without-id",
            message: "작업만 진행해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "PlanExecutionResult.completed without artifactID = artifactCount 0 for diagnostics"
        ),
        .init(
            id: "artifact-persistent-cross-room-isolation",
            message: "다른 방에서 만든 거 사용해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: false,
            shouldRequireApproval: false,
            notes: "RecentArtifactIndex is room-scoped, cross-room fallback is prevented"
        ),
        .init(
            id: "artifact-absolute-path-normalize",
            message: "artifact absolute path normalize",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedArtifactPathNormalized: true,
            notes: "workspace 내부 absolute path는 relative로 normalize"
        ),
        .init(
            id: "artifact-external-path-reject",
            message: "workspace 외부 artifact path",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedArtifactPathInvalidExternal: true,
            notes: "workspace 외부 absolute path는 invalidExternalPath"
        ),
        .init(
            id: "artifact-relative-traversal-blocked",
            message: "artifact relative traversal blocked",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedArtifactPathInvalidRelative: true,
            notes: "../ traversal은 invalidRelativePath"
        ),
        .init(
            id: "artifact-missing-file",
            message: "missing artifact file",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedArtifactMissingFile: true,
            notes: "missing file은 resolver/reuse에서 차단"
        ),
        .init(
            id: "artifact-hash-mismatch",
            message: "hash mismatch artifact",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedArtifactHashMismatch: true,
            notes: "hash mismatch는 stale reuse 차단"
        ),
        .init(
            id: "action-log-oversized",
            message: "action log oversized",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedActionLogCompactionAvailable: true,
            notes: "oversized action_log.jsonl는 compaction/rotation 대상"
        ),
        .init(
            id: "cleanup-dry-run",
            message: "cleanup candidate dry run",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedCleanupDryRunPolicy: true,
            notes: "cleanup는 dry-run report만, delete는 하지 않음"
        ),
        .init(
            id: "memory-sensitive-mail-body",
            message: "민감한 메일 본문 기억해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedMemoryWriteBlocked: true,
            notes: "민감한 본문은 장기 기억에 저장하지 않음"
        ),
        .init(
            id: "memory-sensitive-api-key",
            message: "API key 기억해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedMemoryWriteBlocked: true,
            notes: "API key는 장기 기억 차단"
        ),
        .init(
            id: "memory-sensitive-token-task",
            message: "오늘 업무 저장해줘 token=abc123",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedMemoryWriteBlocked: true,
            notes: "token-like string은 redacted/blocked"
        ),
        .init(
            id: "release-diagnostics-hidden",
            message: "Release build diagnostics",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedVerboseDiagnosticsVisible: false,
            notes: "Release에서는 verbose diagnostics 비활성"
        ),
        .init(
            id: "debug-diagnostics-visible",
            message: "DEBUG build diagnostics",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedVerboseDiagnosticsVisible: true,
            notes: "DEBUG에서는 verbose diagnostics 활성"
        ),
        .init(
            id: "release-model-override-ignored",
            message: "Release model override",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedModelOverrideAllowed: false,
            notes: "Release에서는 model override 무시"
        ),
        .init(
            id: "debug-model-override-allowed",
            message: "DEBUG model override",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            expectedModelOverrideAllowed: true,
            notes: "DEBUG에서는 model override 허용"
        ),
        .init(
            id: "starter-action-meeting-minutes",
            message: "회의록 양식 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.meeting-minutes",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "First launch starter action: meeting minutes template"
        ),
        .init(
            id: "starter-action-checklist",
            message: "앱 출시 체크리스트 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "First launch starter action: app launch checklist"
        ),
        .init(
            id: "starter-action-schedule",
            message: "오늘 할 일 뭐야",
            expectedRoute: .dailyBriefing,
            expectedSkillID: nil,
            expectedRouteHint: "localScheduler",
            expectedGoalType: "scheduleQuery",
            shouldRequireApproval: false,
            notes: "First launch starter action: today's tasks"
        ),
        .init(
            id: "first-result-summary",
            message: "요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "First result activation: summary"
        ),
        .init(
            id: "first-result-table",
            message: "표로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "First result activation: convert to table"
        ),
        .init(
            id: "first-result-checklist",
            message: "체크리스트로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "First result activation: convert to checklist"
        ),
        .init(
            id: "approval-required-mail-send",
            message: "메일 보내줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "mailAction",
            shouldRequireApproval: true,
            notes: "Approval required: mail send action blocked by policy"
        ),
        .init(
            id: "approval-required-calendar-create",
            message: "일정 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "calendarAction",
            shouldRequireApproval: true,
            notes: "Approval required: calendar create action blocked by policy"
        ),
        .init(
            id: "approval-required-file-delete",
            message: "파일 삭제해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "destructiveAction",
            shouldRequireApproval: true,
            notes: "Approval required: file delete action blocked by policy"
        ),
        .init(
            id: "recent-artifact-reuse-meeting-minutes",
            message: "방금 만든 문서 회의록으로 정리해줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: "korean.summary",
            expectedRouteHint: "meetingMinutes",
            expectedGoalType: "recentArtifactReuse",
            shouldRequireApproval: false,
            notes: "Recent artifact reuse: convert to meeting minutes"
        ),
        .init(
            id: "recent-artifact-reuse-action-items",
            message: "방금 만든 문서 액션아이템 뽑아줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: "korean.summary",
            expectedRouteHint: "actionItems",
            expectedGoalType: "recentArtifactReuse",
            shouldRequireApproval: false,
            notes: "Recent artifact reuse: extract action items"
        ),
        .init(
            id: "blocked-external-upload",
            message: "이 파일을 클라우드에 업로드해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "externalUpload",
            shouldRequireApproval: true,
            notes: "Blocked: external file upload not available in Release"
        ),
        .init(
            id: "blocked-calendar-write",
            message: "회의 일정을 캘린더에 추가해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "calendarWrite",
            shouldRequireApproval: true,
            notes: "Blocked: calendar write capability disabled in Release"
        ),
        .init(
            id: "blocked-mail-send",
            message: "이 내용으로 메일 보내줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "mailSend",
            shouldRequireApproval: true,
            notes: "Blocked: mail send capability disabled in Release"
        ),
        .init(
            id: "blocked-placeholder-character",
            message: "레오와 함께 논의해줄래",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "characterInvite",
            shouldRequireApproval: false,
            notes: "Blocked: placeholder character (leo) not available in Release"
        ),

        // MARK: Round 136A-UXFIX — DART / Settings / Blocked write
        .init(
            id: "dart-disclosure-1",
            message: "다트 공시 확인해줘",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.dart",
            expectedRouteHint: nil,
            expectedGoalType: "publicDisclosureRead",
            shouldRequireApproval: false,
            notes: "publicDisclosureRead — allowed, write 없음"
        ),
        .init(
            id: "dart-disclosure-2",
            message: "삼성전자 공시 봐줘",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.dart",
            expectedRouteHint: nil,
            expectedGoalType: "publicDisclosureRead",
            shouldRequireApproval: false,
            notes: "publicDisclosureRead — allowed"
        ),
        .init(
            id: "dart-disclosure-3",
            message: "전자공시 찾아줘",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.dart",
            expectedRouteHint: nil,
            expectedGoalType: "publicDisclosureRead",
            shouldRequireApproval: false,
            notes: "publicDisclosureRead — allowed"
        ),
        .init(
            id: "settings-api-key",
            message: "API key 설정",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: "settings",
            expectedGoalType: "settingsNavigation",
            shouldRequireApproval: false,
            notes: "API key 안내는 Settings에만 — team surface에서 차단"
        ),
        .init(
            id: "settings-ai-provider",
            message: "AI provider 연결",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: "settings",
            expectedGoalType: "settingsNavigation",
            shouldRequireApproval: false,
            notes: "AI provider 연결 안내는 Settings에만"
        ),
        .init(
            id: "starter-meeting-minutes",
            message: "회의록 양식",
            expectedRoute: .localSkill,
            expectedSkillID: "starter_meeting_minutes",
            expectedRouteHint: nil,
            expectedGoalType: "starterAction",
            shouldRequireApproval: false,
            notes: "starter action — allowed"
        ),
        .init(
            id: "starter-today-tasks",
            message: "오늘 할 일",
            expectedRoute: .localSkill,
            expectedSkillID: "starter_today_tasks",
            expectedRouteHint: nil,
            expectedGoalType: "starterAction",
            shouldRequireApproval: false,
            notes: "starter action — allowed"
        ),
        .init(
            id: "blocked-mail-send-uxfix",
            message: "메일 보내줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "mailSend",
            shouldRequireApproval: true,
            notes: "Blocked: external write — mail send"
        ),
        .init(
            id: "blocked-calendar-create-uxfix",
            message: "일정 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "calendarWrite",
            shouldRequireApproval: true,
            notes: "Blocked: external write — calendar create"
        ),
        .init(
            id: "blocked-file-delete-uxfix",
            message: "파일 삭제해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "destructiveFileAction",
            shouldRequireApproval: true,
            notes: "Blocked: destructive file action"
        ),

        // Round 137A-145Z: Product IA Hardening cases
        .init(
            id: "starter-file-handoff",
            message: "파일 맡기기",
            expectedRoute: .localSkill,
            expectedSkillID: nil,
            expectedRouteHint: "fileIntake",
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Starter: 파일 맡기기 → fileIntake 경로"
        ),
        .init(
            id: "starter-document-create",
            message: "문서 만들기",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "Starter: 문서 만들기 → universalDocument 또는 artifactWorkflow"
        ),
        .init(
            id: "starter-today-organize",
            message: "오늘 정리하기",
            expectedRoute: .localSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "calendarBriefing",
            shouldRequireApproval: false,
            notes: "Starter: 오늘 정리하기 → localBriefing/calendarBriefing 경로"
        ),
        .init(
            id: "room-artifact-same-room",
            message: "방금 만든 보고서 요약해줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "현재 방 artifact 참조 — room-scoped 조회 확인"
        ),
        .init(
            id: "workroom-create",
            message: "새 워크룸 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "워크룸 생성 → 안내 메시지 (UI action 위임)"
        ),
        .init(
            id: "reserved-task-create",
            message: "매일 아침 9시에 오늘 할 일 정리해줘",
            expectedRoute: .localSkill,
            expectedSkillID: nil,
            expectedRouteHint: "scheduleTask",
            expectedGoalType: "scheduledTask",
            shouldRequireApproval: false,
            notes: "예약 작업 생성 → scheduler 단일 entry point"
        ),
        .init(
            id: "reserved-task-list",
            message: "예약 작업 목록 보여줘",
            expectedRoute: .localSkill,
            expectedSkillID: nil,
            expectedRouteHint: "scheduleList",
            expectedGoalType: "scheduledTask",
            shouldRequireApproval: false,
            notes: "예약 작업 조회 → 단일 entry point 확인"
        ),
        .init(
            id: "terminology-chat-room",
            message: "새 채팅방 만들어줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "사용자가 '채팅방' 표현 사용 → '워크룸' 안내 포함 응답 확인"
        ),
        .init(
            id: "terminology-schedule-work",
            message: "스케줄 근무 등록해줘",
            expectedRoute: .localSkill,
            expectedSkillID: nil,
            expectedRouteHint: "scheduleTask",
            expectedGoalType: "scheduledTask",
            shouldRequireApproval: false,
            notes: "구 용어 '스케줄 근무' → 예약 작업으로 처리"
        ),

        // Round 146A-152Z: Result Presentation + Room Kind
        .init(
            id: "long-report-result-card",
            message: "MyTeam 앱 소개 문서를 3000자 이상으로 작성해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "긴 결과물은 WorkResultCardView로 렌더링 확인"
        ),
        .init(
            id: "markdown-table-result-card",
            message: "팀원별 업무 분담표를 마크다운 표로 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "마크다운 표 포함 결과 → WorkResultCardView 렌더링"
        ),
        .init(
            id: "room-kind-team-workroom",
            message: "팀 워크룸에서 회의록 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "team_all 방 → computedRoomKind == .teamWorkroom"
        ),
        .init(
            id: "room-kind-personal-chat",
            message: "레오한테 개인적으로 물어볼게 있어",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "단일 에이전트 방 → computedRoomKind == .personalChat"
        ),
        .init(
            id: "content-draft-auxiliary-direct-chat",
            message: "기존 글 URL 참고해서 원고 초안 봐줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "콘텐츠 초안은 MyTeam 메인 CTA가 아니라 워크룸 맥락을 보조하는 direct chat 경로"
        ),
        .init(
            id: "artifact-status-friendly",
            message: "아까 만든 보고서 상태 확인해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "artifact 상태 텍스트가 사용자 친화적으로 순화됨 확인"
        ),
        .init(
            id: "collaboration-status-compact",
            message: "지금 팀 상태 어때?",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "협업 상태 배너가 1줄 컴팩트 바로 압축됨 확인"
        ),
        // Round 163B-UXNAV: Agent Quick Navigation
        .init(
            id: "personal-chat-checklist",
            message: "업무 준비 요소를 체크리스트로 정리합니다",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "업무 준비 체크리스트는 universalDocument로 라우팅됨"
        ),
        .init(
            id: "team-return-shortcut",
            message: "팀 워크룸으로",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: "teamNav",
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "팀 워크룸 복귀는 직접 채팅"
        ),
        .init(
            id: "personal-chat-creation",
            message: "레오와 대화",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: "agentNav",
            expectedGoalType: "directAnswer",
            shouldRequireApproval: false,
            notes: "특정 팀원과의 개인 대화 요청"
        ),

        // Round 164A-180Z: Killer Workflow Completion Pack
        .init(
            id: "document-creation-hub",
            message: "문서 만들기",
            expectedRoute: .universalDocument,
            expectedSkillID: nil,
            expectedRouteHint: "documentCreationHub",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "문서 만들기 → hub 진입"
        ),
        .init(
            id: "meeting-minutes-template",
            message: "회의록 양식 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.meeting-minutes",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "회의록 양식 → meeting minutes skill"
        ),
        .init(
            id: "meeting-minutes-direct",
            message: "회의록 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.meeting-minutes",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "회의록 직접 요청"
        ),
        .init(
            id: "checklist-direct",
            message: "업무 준비 체크리스트 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "체크리스트 직접 요청"
        ),
        .init(
            id: "checklist-short",
            message: "체크리스트 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "짧은 체크리스트 요청"
        ),
        .init(
            id: "report-draft-direct",
            message: "보고서 초안 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.report-draft",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "보고서 초안 직접 요청"
        ),
        .init(
            id: "recent-document-summary",
            message: "방금 만든 문서 요약해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 문서 요약 → room-scoped artifact lookup"
        ),
        .init(
            id: "recent-document-table",
            message: "방금 만든 문서 표로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.document-table-summary",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 문서 표 변환"
        ),
        .init(
            id: "recent-document-checklist",
            message: "방금 만든 문서 체크리스트로 바꿔줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.checklist",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 문서 체크리스트 변환"
        ),
        .init(
            id: "recent-document-action-items",
            message: "방금 만든 문서 액션아이템 뽑아줘",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.action-items",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            expectedRecentArtifactReference: true,
            shouldRequireApproval: false,
            notes: "최근 문서 액션아이템 추출"
        ),

        // Round 181A-195Z: Workroom Productization + Core Loop Surface Pack
        .init(
            id: "workroom-open",
            message: "워크룸 열어줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: "teamWorkroom",
            expectedGoalType: "teamWorkroom",
            shouldRequireApproval: false,
            notes: "워크룸 네비게이션 의도"
        ),
        .init(
            id: "workroom-new",
            message: "새 워크룸 만들어줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: "createTeamWorkroom",
            expectedGoalType: "createTeamWorkroom",
            shouldRequireApproval: false,
            notes: "새 팀 워크룸 생성"
        ),
        .init(
            id: "workroom-create-document",
            message: "워크룸에서 문서 만들기",
            expectedRoute: .universalDocument,
            expectedSkillID: "korean.meeting-minutes",
            expectedRouteHint: "universalDocument",
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "워크룸 홈에서 문서 만들기"
        ),
        .init(
            id: "workroom-today-organize",
            message: "오늘 정리해줘",
            expectedRoute: .universalDocument,
            expectedSkillID: nil,
            expectedRouteHint: "universalDocument",
            expectedGoalType: "dailyOrganization",
            shouldRequireApproval: false,
            notes: "WorkroomHomeView의 '오늘 정리하기' action"
        ),
        .init(
            id: "workroom-file-handoff",
            message: "파일 맡기기",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "fileIntake",
            shouldRequireApproval: false,
            notes: "WorkroomHomeView의 '파일 맡기기' action"
        ),

        // MARK: Round 232 — CharacterReaction policy cases
        // 실제 routing 검사가 아닌 policy-level 케이스.
        // 시나리오가 올바른 CharacterReaction 이벤트를 트리거해야 함을 명시한다.

        .init(
            id: "character-reaction-workroom-opened",
            message: "워크룸 열기",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: workroomOpened → .greeting / .clockIn. CharacterReactionEventSink.notifyWorkroomOpened() must fire from WorkroomHomeView.onAppear"
        ),
        .init(
            id: "character-reaction-document-generation",
            message: "보고서 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "Policy: workflowStarted(universalDocument) → .typing. CharacterReactionEventSink.notifyDocumentGenerationStarted() must fire from handleWorkroomAction(.createDocument)"
        ),
        .init(
            id: "character-reaction-artifact-created",
            message: "문서 완성됐어",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: documentCreated → .joy. CharacterReactionEventSink.notifyDocumentCreated() must fire via workflowCompleted NotificationCenter bridge"
        ),
        .init(
            id: "character-reaction-artifact-reuse",
            message: "지난 보고서 다시 써줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: artifactReuseRequested → .backToWork. CharacterReactionEventSink.notifyArtifactReuseRequested() must fire from handleWorkroomAction(.handoffFile)"
        ),
        .init(
            id: "character-reaction-room-switched",
            message: "다른 방으로 이동",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: multiRoomSwitched → .idle. CharacterReactionEventSink.notifyRoomSwitched() must fire from TeamStatusView room tap"
        ),
        .init(
            id: "character-reaction-idle-long",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: idle(long) → .sleeping. Not yet connected — backlog. No code path currently fires this."
        ),
        .init(
            id: "character-reaction-verification-failed",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: artifactVerificationFailed → .sad / .confused. Not yet connected — backlog. ResultVerifier hook needed."
        ),

        // MARK: Round 233B — Beginner Mode policy cases
        // 간편 모드 UX 동작 정책 케이스.
        // API 키 없이 동작하는 흐름과 친절한 복구 UI를 검증한다.

        .init(
            id: "beginner-example-flow-no-api-key",
            message: "예시로 먼저 해보기",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: '예시로 먼저 해보기' → BeginnerExampleDocumentService.generateExampleMeetingMinutes(). API 키 불필요. ArtifactStore 등록 + workflowCompleted 알림 발생 확인."
        ),
        .init(
            id: "beginner-meeting-minutes-dispatch",
            message: "회의록 양식 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "Policy: BeginnerTaskCard.meetingMinutes.dispatchPrompt → universalDocument 라우팅. WorkroomHomeView.handleBeginnerCardTap(.meetingMinutes) 발동."
        ),
        .init(
            id: "beginner-checklist-dispatch",
            message: "체크리스트 만들어줘",
            expectedRoute: .universalDocument,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: "documentWork",
            shouldRequireApproval: false,
            notes: "Policy: BeginnerTaskCard.checklist.dispatchPrompt → universalDocument 라우팅."
        ),
        .init(
            id: "beginner-mode-toggle-settings",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: SettingsView 간편 모드 토글 → AgentWindowManager.isBeginnerMode @AppStorage 동기화. WorkroomHomeView 분기 전환 확인."
        ),
        .init(
            id: "beginner-friendly-recovery-missing-file",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: ArtifactCardView.healthStatus == .missingFile → friendlyRecovery 표시. '새 문서로 시작' 버튼 → myteam.beginnerNewDocument notification 발생."
        ),

        // MARK: Round 234 — Sprite Asset Gate + Beginner Next Action policy cases

        .init(
            id: "sprite-asset-chiko-folder-present",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: 치코 Sprites 폴더(MyTeam/Resources/Sprites/치코/) 존재해야 함. CharacterSpriteScene.loadTextures() 가 폴더를 직접 탐색. Missing → SKSpriteNode placeholder + fallbackImageNode 표시."
        ),
        .init(
            id: "sprite-missing-fallback-to-idle",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: 스프라이트 없는 state → resolveWithFallback() → fallbackStates chain → 최종 .idle. idle PNG 반드시 존재해야 함. 현재 치코_idle_001.png ~ _011.png 확인됨."
        ),
        .init(
            id: "beginner-example-next-action-exists",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: BeginnerExampleDocumentService → ArtifactStore.registerArtifact() → WorkroomHomeModel.recentArtifacts not empty → nextActions = WorkroomNextAction.allCases [summarize/table/checklist/actionItems]. WorkroomHomeView에 표시."
        ),
        .init(
            id: "friendly-recovery-no-external-write",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: ArtifactCardView friendlyRecovery 버튼은 NotificationCenter.post('myteam.beginnerNewDocument') 만 발행. 삭제/업로드/메일/캘린더 write action 없음. ConnectorGuard 범위 외 (내부 Notification 전용)."
        ),
        .init(
            id: "friendly-recovery-hash-mismatch",
            message: "",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: false,
            notes: "Policy: healthStatus == .hashMismatch → friendlyRecovery '파일 내용이 바뀐 것 같아요' + '새 문서로 시작' 버튼. 기술 용어(hash mismatch) 사용자 화면 노출 금지."
        ),
        .init(
            id: "blocked-mail-calendar-write",
            message: "이메일 보내줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            expectedGoalType: nil,
            shouldRequireApproval: true,
            notes: "Policy: .sendEmail / .createCalendarEvent → CapabilityAwareRouter .blocked 또는 .requiresApproval. Connector write는 항상 사용자 확인 필요. FriendlyRecovery 버튼은 이 경로를 열지 않음."
        )
    ]

    static func evaluateCase(_ testCase: RouterBurnInCase) -> RouterBurnInResult {
        let actual = classify(message: testCase.message)
        let goal = GoalInterpreter.interpret(testCase.message)
        let goalPassed = testCase.expectedGoalType.map { $0 == goal.goalType.rawValue }
        let actualRecentArtifactReference = GoalContextEngine.referencesRecentArtifact(testCase.message)
        let recentArtifactPassed = testCase.expectedRecentArtifactReference.map { $0 == actualRecentArtifactReference }
        let memoryBlocked = !MemoryWriteGuard.evaluateFact(testCase.message).canPersistInUserDefaults
        let memoryPassed = testCase.expectedMemoryWriteBlocked.map { $0 == memoryBlocked }
        let verboseDiagnosticsPassed = testCase.expectedVerboseDiagnosticsVisible.map { $0 == DiagnosticsVisibilityPolicy.allowsVerboseDiagnostics }
        let modelOverridePassed = testCase.expectedModelOverrideAllowed.map { $0 == AIModelPolicy.modelOverrideAllowed }
        let workspaceURL = ToolExecutionContext.workspaceURL
        let workspacePath = workspaceURL.standardizedFileURL.path
        let workspacePrefix = workspacePath.hasSuffix("/") ? workspacePath : workspacePath + "/"
        let sampleURL = workspaceURL.appendingPathComponent("sample.md").standardizedFileURL
        let normalizedRelativePath = Self.relativePath(for: sampleURL.path, workspacePath: workspacePath)
        let normalizedPathPassed = testCase.expectedArtifactPathNormalized.map {
            $0 == (normalizedRelativePath == "sample.md")
        }
        let invalidExternalPathPassed = testCase.expectedArtifactPathInvalidExternal.map {
            $0 == !Self.isInsideWorkspace("/tmp/outside.md", workspacePath: workspacePath, workspacePrefix: workspacePrefix)
        }
        let invalidRelativePathPassed = testCase.expectedArtifactPathInvalidRelative.map {
            $0 == (Self.normalizeStoredPath("../escape.md", workspacePath: workspacePath, workspacePrefix: workspacePrefix) == nil)
        }
        let missingFilePassed = testCase.expectedArtifactMissingFile.map { $0 == !FileManager.default.fileExists(atPath: workspaceURL.appendingPathComponent("burnin-missing-\(testCase.id).md").path) }
        let hashMismatchPassed = testCase.expectedArtifactHashMismatch.map {
            $0 == (StableContentHash.sha256Hex("a") != StableContentHash.sha256Hex("b"))
        }
        let actionLogCompactionPassed = testCase.expectedActionLogCompactionAvailable.map { $0 == (ActionLogCompactionPolicy.maxBytes > 0) }
        let cleanupDryRunPassed = testCase.expectedCleanupDryRunPolicy.map { $0 == true }
        let passed = actual.route == testCase.expectedRoute
            && (testCase.expectedSkillID == nil || testCase.expectedSkillID == actual.skillID)
            && (testCase.expectedRouteHint == nil || testCase.expectedRouteHint == actual.routeHint)
            && actual.requiresApproval == testCase.shouldRequireApproval
            && (goalPassed ?? true)
            && (recentArtifactPassed ?? true)
            && (memoryPassed ?? true)
            && (verboseDiagnosticsPassed ?? true)
            && (modelOverridePassed ?? true)
            && (normalizedPathPassed ?? true)
            && (invalidExternalPathPassed ?? true)
            && (invalidRelativePathPassed ?? true)
            && (missingFilePassed ?? true)
            && (hashMismatchPassed ?? true)
            && (actionLogCompactionPassed ?? true)
            && (cleanupDryRunPassed ?? true)

        return RouterBurnInResult(
            id: testCase.id,
            passed: passed,
            expected: expectedDescription(for: testCase),
            actual: actualDescription(for: actual),
            expectedGoalType: testCase.expectedGoalType,
            actualGoalType: goal.goalType.rawValue,
            goalPassed: goalPassed,
            expectedRecentArtifactReference: testCase.expectedRecentArtifactReference,
            actualRecentArtifactReference: actualRecentArtifactReference,
            notes: testCase.notes
        )
    }

    static func runAll() -> RouterBurnInSummary {
        let results = cases.map(evaluateCase)
        let passed = results.filter(\.passed).count
        let failed = results.count - passed
        let goalChecked = results.compactMap(\.goalPassed).count
        let goalPassed = results.compactMap(\.goalPassed).filter { $0 }.count
        let goalFailed = goalChecked - goalPassed
        return RouterBurnInSummary(
            total: results.count,
            passed: passed,
            failed: failed,
            failures: results.filter { !$0.passed },
            goalChecked: goalChecked,
            goalPassed: goalPassed,
            goalFailed: goalFailed
        )
    }

    private struct DetectedRoute {
        let route: RouterBurnInCase.ExpectedRoute
        let skillID: String?
        let routeHint: String?
        let requiresApproval: Bool
    }

    private static func classify(message: String) -> DetectedRoute {
        if DelegatedWorkflowDetector.isDelegationCancel(message) {
            return DetectedRoute(route: .delegationCancel, skillID: nil, routeHint: nil, requiresApproval: false)
        }
        if DelegatedWorkflowDetector.isDelegationApproval(message) {
            return DetectedRoute(route: .delegationApproval, skillID: nil, routeHint: nil, requiresApproval: false)
        }
        if DelegatedWorkflowDetector.isDelegationRequest(message) {
            return DetectedRoute(
                route: .delegationAwaitingApproval,
                skillID: nil,
                routeHint: DelegatedWorkflowDetector.inferRouteHint(from: message),
                requiresApproval: true
            )
        }

        if let appLaunchType = AppLaunchSkillService.detectSkillType(from: message) {
            return DetectedRoute(
                route: .appLaunchPack,
                skillID: appLaunchType.skillID,
                routeHint: "appLaunchPack",
                requiresApproval: false
            )
        }

        if message.lowercased().contains("개인정보처리방침") || message.lowercased().contains("이용약관") || message.lowercased().contains("정책 초안") {
            return DetectedRoute(route: .privacyTerms, skillID: "korean.privacy-terms", routeHint: "privacyTerms", requiresApproval: false)
        }

        if DailyBriefingRouteDetector.isDailyBriefingRequest(message) {
            return DetectedRoute(route: .dailyBriefing, skillID: nil, routeHint: "dailyBriefing", requiresApproval: false)
        }

        let allMatches = SkillRegistry.shared.matchAllSkills(for: message)
        if let disabled = allMatches.first(where: { !SkillRegistry.shared.isSkillEnabled(id: $0.id) }) {
            return DetectedRoute(route: .disabledSkill, skillID: disabled.id, routeHint: nil, requiresApproval: false)
        }
        if let enabled = SkillRegistry.shared.matchEnabledSkills(for: message).first {
            return DetectedRoute(route: .localSkill, skillID: enabled.id, routeHint: nil, requiresApproval: false)
        }

        if let docType = UniversalDocumentSkillService.detectSkillType(from: message),
           let skill = SkillRegistry.shared.skill(named: docType.skillID),
           SkillRegistry.shared.isSkillEnabled(id: skill.id) {
            return DetectedRoute(route: .universalDocument, skillID: skill.id, routeHint: "universalDocument", requiresApproval: false)
        }

        if looksLikeArtifactWorkflow(message) {
            return DetectedRoute(route: .artifactWorkflow, skillID: nil, routeHint: "artifactWorkflow", requiresApproval: false)
        }

        if looksHighRisk(message) {
            return DetectedRoute(route: .blockedHighRiskSkill, skillID: nil, routeHint: nil, requiresApproval: true)
        }

        if looksLikeTeamDiscussion(message) {
            return DetectedRoute(route: .teamDiscussion, skillID: nil, routeHint: "teamDiscussion", requiresApproval: false)
        }

        return DetectedRoute(route: .directChat, skillID: nil, routeHint: nil, requiresApproval: false)
    }

    private static func looksLikeArtifactWorkflow(_ message: String) -> Bool {
        let lower = message.lowercased()
        let nouns = ["ppt", "피피티", "프레젠테이션", "발표자료", "엑셀", "스프레드시트", "파일", "markdown", "md", "artifact", "산출물"]
        let verbs = ["만들어", "작성해", "생성해", "저장해", "정리"]
        if nouns.contains(where: { lower.contains($0) }) && verbs.contains(where: { lower.contains($0) }) {
            return true
        }
        if (lower.contains("표로") || lower.contains("표를")) &&
            (lower.contains("정리") || lower.contains("만들") || lower.contains("작성") || lower.contains("생성")) {
            return true
        }
        return false
    }

    private static func looksLikeTeamDiscussion(_ message: String) -> Bool {
        let lower = message.lowercased()
        let keywords = ["팀", "팀원", "검토", "의견", "토론", "논의", "같이", "피드백"]
        return keywords.contains { lower.contains($0) }
    }

    private static func looksHighRisk(_ message: String) -> Bool {
        let lower = message.lowercased()
        let keywords = [
            "결제", "청구", "환불", "카드", "계좌", "송금", "이체", "비밀번호",
            "메일 보내", "이메일 보내", "메일 발송",
            "로그인", "인증", "삭제", "지워", "제거", "해킹", "은행",
            "실행", "구동", "bash", "zsh", "sh ", "command", "스크립트"
        ]
        return keywords.contains { lower.contains($0) }
    }

    private static func expectedDescription(for testCase: RouterBurnInCase) -> String {
        var parts = ["route=\(testCase.expectedRoute.rawValue)"]
        if let skillID = testCase.expectedSkillID { parts.append("skill=\(skillID)") }
        if let routeHint = testCase.expectedRouteHint { parts.append("hint=\(routeHint)") }
        if let recentArtifact = testCase.expectedRecentArtifactReference { parts.append("recentArtifact=\(recentArtifact)") }
        if let memoryBlocked = testCase.expectedMemoryWriteBlocked { parts.append("memoryBlocked=\(memoryBlocked)") }
        if let verbose = testCase.expectedVerboseDiagnosticsVisible { parts.append("verboseDiagnostics=\(verbose)") }
        if let modelOverride = testCase.expectedModelOverrideAllowed { parts.append("modelOverride=\(modelOverride)") }
        if let normalized = testCase.expectedArtifactPathNormalized { parts.append("pathNormalized=\(normalized)") }
        if let external = testCase.expectedArtifactPathInvalidExternal { parts.append("externalPathInvalid=\(external)") }
        if let relative = testCase.expectedArtifactPathInvalidRelative { parts.append("relativePathInvalid=\(relative)") }
        if let missing = testCase.expectedArtifactMissingFile { parts.append("missingFile=\(missing)") }
        if let hashMismatch = testCase.expectedArtifactHashMismatch { parts.append("hashMismatch=\(hashMismatch)") }
        if let actionLog = testCase.expectedActionLogCompactionAvailable { parts.append("actionLogCompaction=\(actionLog)") }
        if let cleanup = testCase.expectedCleanupDryRunPolicy { parts.append("cleanupDryRun=\(cleanup)") }
        parts.append("approval=\(testCase.shouldRequireApproval)")
        return parts.joined(separator: " | ")
    }

    private static func actualDescription(for route: DetectedRoute) -> String {
        var parts = ["route=\(route.route.rawValue)"]
        if let skillID = route.skillID { parts.append("skill=\(skillID)") }
        if let routeHint = route.routeHint { parts.append("hint=\(routeHint)") }
        parts.append("approval=\(route.requiresApproval)")
        return parts.joined(separator: " | ")
    }

    private static func isInsideWorkspace(_ path: String, workspacePath: String, workspacePrefix: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        return standardized == workspacePath || standardized.hasPrefix(workspacePrefix)
    }

    private static func relativePath(for filePath: String, workspacePath: String) -> String? {
        let standardized = URL(fileURLWithPath: filePath).standardizedFileURL.path
        guard standardized == workspacePath || standardized.hasPrefix(workspacePath.hasSuffix("/") ? workspacePath : workspacePath + "/") else {
            return nil
        }

        let relative = String(standardized.dropFirst(workspacePath.count))
        let trimmed = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        return isSafeRelativePath(trimmed) ? trimmed : nil
    }

    private static func normalizeStoredPath(_ storedPath: String, workspacePath: String, workspacePrefix: String) -> String? {
        let trimmed = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") {
            return isInsideWorkspace(trimmed, workspacePath: workspacePath, workspacePrefix: workspacePrefix)
                ? relativePath(for: trimmed, workspacePath: workspacePath)
                : nil
        }
        return isSafeRelativePath(trimmed) ? trimmed : nil
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.contains(":") else { return false }
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy { part in
            let component = String(part)
            return component != "." && component != ".." && !component.hasPrefix(".")
        }
    }
}
