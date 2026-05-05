import Foundation

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
        dartSkill
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
        version: "1.0",
        description: "한국어 텍스트의 글자 수·바이트·공백 포함/제외 등을 계산한다. 자소서·NEIS 등 제출용 카운트 지원",
        locale: "ko-KR",
        category: .koreanWriting,
        triggers: ["글자 수", "byte", "바이트", "자소서", "NEIS"],
        allowedScopes: [.chatBasic],
        requiredPermissions: [],
        requiredLogin: false,
        riskLevel: .safeReadOnly,
        promptTemplate: "사용자가 한국어 텍스트의 글자 수 계산을 요청했습니다. 공백 포함/제외 글자 수, 바이트(UTF-8), 줄 수를 계산해 주세요.",
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
        defaultEnabled: false,
        requiresApprovalEveryRun: false,
        backendHint: "dart-open-api",
        notes: [
            "투자 조언 아님 — 공시 데이터 요약",
            "수치 미확인 시 추측 금지",
            "미구현: DART Open API 연동 (Round 7 이후)"
        ]
    )
}
