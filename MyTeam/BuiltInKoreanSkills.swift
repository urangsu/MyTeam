import Foundation

// MARK: - FeatureAvailability (Round 246A: P1-3)
// 스킬/기능이 실제로 어느 수준까지 동작하는지 명시.
// fake available(❌) / 완전 숨김(❌) / assistOnly(✅ — LLM 보조, 외부 API 없음)

enum FeatureAvailability {
    case available     // 실제 동작 (외부 API 연결됨)
    case assistOnly    // LLM 보조만 가능, 외부 API 미연결
    case planned       // 개발 예정, 숨김
    case blocked       // 정책상 차단
}

// MARK: - BuiltInKoreanSkills
// caseless enum 네임스페이스 (AutomationPolicy 패턴과 동일)
// BuiltInKoreanSkills.all → SkillRegistry에서 로드

enum BuiltInKoreanSkills {

    static let all: [SkillManifest] = [
        weatherSkill,
        fineDustSkill,
        spellCheckSkill,
        characterCountSkill,
        naverNewsSkill,
        naverBlogResearchSkill,
        privacyTermsSkill,
        hwpReadSkill,
        lawSearchSkill,
        dartSkill,
        appStoreCopySkill,
        onboardingCopySkill,
        launchChecklistSkill,
        monetizationReviewSkill,
        documentSummarySkill,
        reportDraftSkill,
        checklistSkill,
        tableSummarySkill,
        meetingMinutesSkill,
        actionItemsSkill
    ]

    // MARK: - 1. 한국 날씨

    private static let weatherSkill = SkillManifest(
        id: "korean.weather",
        name: "한국 날씨 조회",
        version: "1.0",
        description: "한국 지역 날씨 정보를 공공 기상 데이터로 조회·요약한다",
        locale: "ko-KR",
        category: .koreanLife,
        triggers: ["날씨", "기상", "비 와", "우산"],
        allowedScopes: [.chatBasic],
        requiredPermissions: [.usePublicWeb, .useKoreanPublicData],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: "사용자가 한국 날씨 정보를 요청했습니다. 지역({location})의 현재 날씨와 오늘 예보를 간략히 요약하세요.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 2. 미세먼지

    private static let fineDustSkill = SkillManifest(
        id: "korean.fine-dust",
        name: "미세먼지 조회",
        version: "1.0",
        description: "한국 지역 미세먼지(PM10)·초미세먼지(PM2.5)·공기질(AQI)을 조회한다",
        locale: "ko-KR",
        category: .koreanLife,
        triggers: ["미세먼지", "초미세먼지", "공기질"],
        allowedScopes: [.chatBasic],
        requiredPermissions: [.usePublicWeb, .useKoreanPublicData],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: "사용자가 미세먼지 또는 공기질 정보를 요청했습니다. 지역({location})의 현재 PM10·PM2.5 수치와 등급을 알려주세요.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 3. 한국어 맞춤법 검사

    private static let spellCheckSkill = SkillManifest(
        id: "korean.spell-check",
        name: "한국어 맞춤법 검사",
        version: "1.0",
        description: "사용자가 입력한 한국어 텍스트의 맞춤법·문법 오류를 검사하고 교정안을 제시한다",
        locale: "ko-KR",
        category: .koreanWriting,
        triggers: ["맞춤법", "교정", "문법 검사"],
        allowedScopes: [.chatBasic, .artifactGeneration],
        requiredPermissions: [.usePublicAPI],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 한국어 맞춤법 검사를 요청했습니다. 입력 텍스트의 오류를 찾아 교정안을 제시하세요. 변경 이유도 간략히 설명하세요.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 4. 한국어 글자 수 세기

    private static let characterCountSkill = SkillManifest(
        id: "korean.character-count",
        name: "한국어 글자 수 세기",
        version: "1.1",
        description: "한국어 텍스트의 공백 포함/제외 글자 수, UTF-8 bytes, 제출폼 기준 bytes를 로컬에서 계산한다",
        locale: "ko-KR",
        category: .koreanWriting,
        triggers: ["글자 수", "글자수", "byte", "바이트", "자소서", "NEIS"],
        allowedScopes: [.chatBasic],
        requiredPermissions: [],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 한국어 글자 수 계산을 요청했습니다. 공백 포함/제외 글자 수, UTF-8 bytes, 제출폼 기준 bytes, 줄 수, 문단 수를 기기 내에서 계산하세요. 외부 API 호출은 없습니다.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 5. 네이버 뉴스 검색

    private static let naverNewsSkill = SkillManifest(
        id: "korean.naver-news",
        name: "네이버 뉴스 검색",
        version: "1.0",
        description: "네이버 뉴스에서 키워드 관련 최신 기사를 검색·요약한다",
        locale: "ko-KR",
        category: .koreanLife,
        triggers: ["네이버 뉴스", "뉴스 검색", "최신 뉴스"],
        allowedScopes: [.chatBasic, .browserDOM],
        requiredPermissions: [.usePublicWeb, .useWebEvidence],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: "사용자가 네이버 뉴스 검색을 요청했습니다. 키워드 관련 최신 기사 3-5개를 요약하고 출처 URL을 함께 제공하세요.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 6. 네이버 블로그 리서치

    private static let naverBlogResearchSkill = SkillManifest(
        id: "korean.naver-blog-research",
        name: "네이버 블로그 리서치",
        version: "1.0",
        description: "네이버 블로그에서 키워드 관련 후기·리뷰·정보를 수집하고 요약 리포트를 생성한다",
        locale: "ko-KR",
        category: .koreanWriting,
        triggers: ["네이버 블로그", "블로그 리서치", "블로그 후기", "키워드 분석"],
        allowedScopes: [.chatBasic, .browserDOM, .artifactGeneration],
        requiredPermissions: [.usePublicWeb, .useWebEvidence],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: "사용자가 네이버 블로그 리서치를 요청했습니다. 키워드 관련 블로그 후기를 수집하고 핵심 내용을 요약 정리하세요.",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 7. 개인정보처리방침·이용약관 생성

    private static let privacyTermsSkill = SkillManifest(
        id: "korean.privacy-terms",
        name: "한국 개인정보처리방침·이용약관 생성",
        version: "1.0",
        description: "한국 개인정보보호법 기준에 맞는 개인정보처리방침, 이용약관, 쿠키 동의 모달 초안을 생성한다",
        locale: "ko-KR",
        category: .koreanBusiness,
        triggers: ["개인정보처리방침", "이용약관", "약관", "쿠키 배너", "동의 모달"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact, .legalOrAdministrative],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: "사용자가 한국 개인정보처리방침 또는 이용약관 문서 생성을 요청했습니다. 개인정보보호법 기준에 맞는 초안을 작성하고, 실제 서비스에 맞게 수정이 필요한 항목을 표시하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 8. HWP 문서 조회/변환

    private static let hwpReadSkill = SkillManifest(
        id: "korean.hwp-read",
        name: "HWP 문서 조회/변환",
        version: "1.0",
        description: "Workspace에 업로드된 HWP/HWPX 파일의 텍스트를 추출하거나 마크다운으로 변환한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["hwp", "hwpx", "한글 문서", "한글파일"],
        allowedScopes: [.documentEditing, .artifactGeneration],
        requiredPermissions: [.readWorkspaceFile, .createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 HWP 문서 처리를 요청했습니다. Workspace의 HWP/HWPX 파일에서 텍스트를 추출하고 마크다운 형식으로 정리하세요.",
        outputType: .markdown,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 9. 한국 법령 검색

    private static let lawSearchSkill = SkillManifest(
        id: "korean.law-search",
        name: "한국 법령 검색",
        version: "1.0",
        description: "법제처 API·공개 법령 데이터로 조문·판례를 검색하고 요약한다. 법률 자문이 아닌 참고용 검색·요약 서비스",
        locale: "ko-KR",
        category: .koreanLegal,
        triggers: ["법령", "조문", "판례", "시행령", "법률"],
        allowedScopes: [.chatBasic, .browserDOM],
        requiredPermissions: [.usePublicAPI, .useKoreanPublicData, .legalOrAdministrative],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: """
사용자가 한국 법령 또는 판례를 검색 요청했습니다.
검색 결과를 요약할 때 다음 원칙을 반드시 따르세요:
1. 이 답변은 법률 전문가의 자문이 아니라 참고용 검색·요약입니다. 중요한 법적 판단은 변호사에게 확인하세요.
2. 조문 번호와 출처(법령명, 조항)를 반드시 명시하세요.
3. 검색으로 확인되지 않은 조문·판례는 추측하거나 임의로 작성하지 마세요.
4. 시행일·개정 이력이 중요한 경우 최신 시행일을 함께 안내하세요.
""",
        outputType: .chat,
        isBuiltIn: true,
        defaultEnabled: false,
        requiresApprovalEveryRun: false,
        backendHint: "korean-law-mcp",
        notes: [
            "법률 자문 아님 — 참고용 요약",
            "조문 미확인 시 추측 금지",
            "requiresCitationVerification: true",
            "미구현: 법제처 Open API 연동 (Round 7 이후)"
        ]
    )

    // MARK: - 10. DART 공시 조회

    private static let dartSkill = SkillManifest(
        id: "korean.dart",
        name: "DART 공시 조회",
        version: "1.0",
        description: "금융감독원 DART 공시 데이터(사업보고서·재무제표·감사의견)를 조회하고 요약한다. 투자 조언이 아닌 공시 데이터 요약",
        locale: "ko-KR",
        category: .koreanFinance,
        triggers: ["DART", "공시", "사업보고서", "재무제표", "감사의견"],
        allowedScopes: [.chatBasic, .browserDOM],
        requiredPermissions: [.usePublicAPI, .financialData],
        requiredLogin: false,
        riskLevel: .publicData,
        promptTemplate: """
사용자가 DART 공시 데이터 조회를 요청했습니다.
다음 원칙을 따르세요:
1. 이 답변은 투자 조언이 아니라 공시 데이터 요약입니다. 투자 결정은 본인 판단으로 하세요.
2. 수치(매출, 영업이익, 부채비율 등)는 출처 공시명과 기준일을 함께 명시하세요.
3. 확인되지 않은 수치는 임의로 작성하지 마세요.
""",
        outputType: .chat,
        isBuiltIn: true,
        // Round 246A: assistOnly — DART Open API 미연결, LLM 보조만 가능
        // 사용자 응답: "DART API 직접 조회는 아직 연결 전입니다.
        //   종목명, 공시 PDF, 사업보고서 내용을 주시면 공시 요약 형식으로 정리해드릴 수 있어요."
        // featureAvailability: .assistOnly
        defaultEnabled: true,   // 스킬 매칭은 되지만 외부 API 없이 LLM 보조
        requiresApprovalEveryRun: false,
        backendHint: "dart-open-api",
        notes: [
            "publicDisclosureRead — 공개 공시 조회, write 없음, OAuth 없음",
            "투자 조언 아님 — 공시 데이터 요약",
            "수치 미확인 시 추측 금지",
            "[246A] featureAvailability=assistOnly: DART Open API 미연결, LLM 보조만",
            "사용자에게: 'API 직접 조회는 아직 연결 전, 자료 주시면 공시 형식으로 정리'"
        ]
    )

    // MARK: - 11. 앱스토어 설명문 생성

    private static let appStoreCopySkill = SkillManifest(
        id: "korean.app-store-copy",
        name: "앱스토어 설명문 생성",
        version: "1.0",
        description: "앱스토어 소개문, Subtitle, Promotional Text, Description 초안을 생성한다",
        locale: "ko-KR",
        category: .koreanBusiness,
        triggers: ["앱스토어", "App Store", "소개문", "설명문", "메타데이터", "subtitle", "promotional text"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 앱스토어 설명문 초안을 요청했습니다. 앱의 핵심 가치, 주요 기능, 추천 키워드, 심사 전 확인사항을 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 12. 온보딩 문구 생성

    private static let onboardingCopySkill = SkillManifest(
        id: "korean.onboarding-copy",
        name: "온보딩 문구 생성",
        version: "1.0",
        description: "첫 실행 온보딩, 환영 문구, 권한 안내, 빈 상태 문구, CTA 문구를 생성한다",
        locale: "ko-KR",
        category: .koreanBusiness,
        triggers: ["온보딩", "첫 화면", "튜토리얼", "시작 문구", "welcome", "onboarding"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 온보딩 문구 초안을 요청했습니다. 3-step 온보딩, 첫 실행 환영 문구, 권한 안내, 빈 상태 문구, CTA 문구를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 13. 출시 체크리스트 생성

    private static let launchChecklistSkill = SkillManifest(
        id: "korean.launch-checklist",
        name: "출시 체크리스트 생성",
        version: "1.0",
        description: "앱 출시 전 메타데이터, 약관, SDK, 권한, 테스트, 심사, 모니터링 체크리스트를 생성한다",
        locale: "ko-KR",
        category: .koreanBusiness,
        triggers: ["출시 체크리스트", "앱 출시 준비", "배포 전 점검", "심사 준비"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 출시 체크리스트 초안을 요청했습니다. 앱스토어 메타데이터, 개인정보/약관, 분석/광고/결제 SDK, 권한 문구, 테스트, 심사 제출, 출시 후 모니터링 항목을 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 14. 수익화 점검표 생성

    private static let monetizationReviewSkill = SkillManifest(
        id: "korean.monetization-review",
        name: "수익화 점검표 생성",
        version: "1.0",
        description: "광고, 구독, 인앱결제, 가격 실험, 무료/Pro 경계, BYOK 정책을 점검하는 문서를 생성한다",
        locale: "ko-KR",
        category: .koreanBusiness,
        triggers: ["수익화", "구독", "광고", "인앱결제", "가격", "BM", "monetization"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 수익화 점검표 초안을 요청했습니다. 현재 BM 가정, 광고, 구독, 인앱결제, 가격 실험, 무료/Pro 경계, BYOK 정책, 리스크, 다음 액션을 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 15. 문서 요약

    private static let documentSummarySkill = SkillManifest(
        id: "korean.document-summary",
        name: "문서 요약",
        version: "1.0",
        description: "긴 문서를 핵심 요약, 주요 내용, 조건, 리스크, 다음 액션으로 정리한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["요약", "문서 요약", "핵심 요약", "정리해줘"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 문서 요약 초안을 요청했습니다. 작성 가정, 핵심 요약, 주요 내용, 중요한 조건, 리스크, 다음 액션, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 16. 보고서 초안

    private static let reportDraftSkill = SkillManifest(
        id: "korean.report-draft",
        name: "보고서 초안",
        version: "1.0",
        description: "업무 보고서 초안을 목적, 배경, 현황, 이슈, 검토 의견, 제안, 다음 액션으로 정리한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["보고서", "보고서 초안", "검토 보고서", "리포트"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 보고서 초안을 요청했습니다. 작성 가정, 목적, 배경, 현황, 주요 이슈, 검토 의견, 제안, 다음 액션, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 17. 체크리스트

    private static let checklistSkill = SkillManifest(
        id: "korean.checklist",
        name: "체크리스트",
        version: "1.0",
        description: "준비/진행/완료 전/리스크/TODO 중심 체크리스트를 작성한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["체크리스트", "점검표", "할 일 목록"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 체크리스트 초안을 요청했습니다. 작성 가정, 사전 준비, 진행 중 확인사항, 완료 전 점검, 리스크 체크, 우선순위 높은 TODO, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 18. 표 정리

    private static let tableSummarySkill = SkillManifest(
        id: "korean.table-summary",
        name: "표 정리",
        version: "1.0",
        description: "정보를 표로 정리하고 항목별 설명, 빠진 정보, 다음 액션을 함께 작성한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["표로 정리", "표 정리", "표", "비교표"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 표 정리를 요청했습니다. 작성 가정, 요약 표, 항목별 설명, 빠진 정보, 다음 액션, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 19. 회의록 정리

    private static let meetingMinutesSkill = SkillManifest(
        id: "korean.meeting-minutes",
        name: "회의록 정리",
        version: "1.0",
        description: "회의 목적, 논의사항, 결정사항, 액션아이템, 후속 확인사항을 정리한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["회의록", "회의록처럼", "회의 내용", "미팅 정리"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 회의록 정리를 요청했습니다. 작성 가정, 회의 목적, 논의사항, 결정사항, 액션아이템, 후속 확인사항, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )

    // MARK: - 20. 액션아이템 추출

    private static let actionItemsSkill = SkillManifest(
        id: "korean.action-items",
        name: "액션아이템 추출",
        version: "1.0",
        description: "회의나 문서에서 바로 할 일, 이번 주 할 일, 확인이 필요한 일, 담당자/기한을 추출한다",
        locale: "ko-KR",
        category: .document,
        triggers: ["액션아이템", "액션 아이템", "해야 할 일", "다음 액션", "todo"],
        allowedScopes: [.artifactGeneration, .documentEditing],
        requiredPermissions: [.createArtifact],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 액션아이템 추출을 요청했습니다. 작성 가정, 바로 할 일, 이번 주 할 일, 확인이 필요한 일, 담당자/기한 정리, 다음 확인 질문, 다음 수정 포인트를 포함한 마크다운 초안을 작성하세요.",
        outputType: .artifact,
        isBuiltIn: true,
        defaultEnabled: true,
        requiresApprovalEveryRun: false
    )
}
