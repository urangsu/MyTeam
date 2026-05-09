import Foundation

enum RouterBurnInSuite {
    static let cases: [RouterBurnInCase] = [
        .init(
            id: "app-launch-copy-ad",
            message: "IMMM 앱스토어 설명문 만들어줘. 광고를 써.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.app-store-copy",
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: false,
            notes: "명시적 앱스토어 문서 타입이 광고 키워드보다 우선"
        ),
        .init(
            id: "app-launch-onboarding-subscription",
            message: "IMMM 온보딩 문구 만들어줘. 구독은 없어.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.onboarding-copy",
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: false,
            notes: "온보딩 문서 타입 우선"
        ),
        .init(
            id: "app-launch-checklist-adsdk",
            message: "IMMM 출시 체크리스트 만들어줘. 광고 SDK 써.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.launch-checklist",
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: false,
            notes: "출시 체크리스트 우선"
        ),
        .init(
            id: "app-launch-monetization",
            message: "IMMM 수익화 점검표 만들어줘. 광고와 구독 고민 중이야.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.monetization-review",
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: false,
            notes: "명시적 수익화 문서만 monetizationReview로 라우팅"
        ),
        .init(
            id: "app-launch-missing-name",
            message: "광고를 쓰는 앱이야. 앱스토어 설명문 만들어줘.",
            expectedRoute: .appLaunchPack,
            expectedSkillID: "korean.app-store-copy",
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: false,
            notes: "앱 이름 누락이면 질문/가정 경로"
        ),
        .init(
            id: "delegation-app-launch",
            message: "IMMM 출시 준비 맡길게. 앱스토어 설명문이랑 온보딩까지 알아서 만들어줘.",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "appLaunchPack",
            shouldRequireApproval: true,
            notes: "위임 요청은 승인 대기 상태로 전환"
        ),
        .init(
            id: "delegation-approval",
            message: "진행해",
            expectedRoute: .delegationApproval,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "승인 표현"
        ),
        .init(
            id: "delegation-cancel",
            message: "위임모드 종료",
            expectedRoute: .delegationCancel,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "종료 표현"
        ),
        .init(
            id: "delegation-mail",
            message: "메일 보내기까지 알아서 해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            shouldRequireApproval: true,
            notes: "외부 전송은 재승인 필요"
        ),
        .init(
            id: "delegation-payment",
            message: "결제까지 알아서 진행해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            shouldRequireApproval: true,
            notes: "결제는 차단 또는 재승인 경계"
        ),
        .init(
            id: "privacy-terms-basic",
            message: "내 IMMM 앱 개인정보처리방침과 이용약관 초안 만들어줘",
            expectedRoute: .privacyTerms,
            expectedSkillID: "korean.privacy-terms",
            expectedRouteHint: "privacyTerms",
            shouldRequireApproval: false,
            notes: "개인정보처리방침 / 이용약관 라우팅"
        ),
        .init(
            id: "privacy-terms-ownership",
            message: "삼성 공식 개인정보처리방침 만들어줘",
            expectedRoute: .privacyTerms,
            expectedSkillID: "korean.privacy-terms",
            expectedRouteHint: "privacyTerms",
            shouldRequireApproval: false,
            notes: "소유권 확인 문구가 필요할 수 있음"
        ),
        .init(
            id: "local-character-count",
            message: "글자 수 세줘: 안녕하세요",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.character-count",
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "완전 로컬 처리"
        ),
        .init(
            id: "local-spell-check",
            message: "이 문장 맞춤법 검사해줘",
            expectedRoute: .localSkill,
            expectedSkillID: "korean.spell-check",
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "활성 스킬 매칭"
        ),
        .init(
            id: "artifact-report",
            message: "MyTeam 소개 보고서 만들어줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            shouldRequireApproval: false,
            notes: "artifact workflow"
        ),
        .init(
            id: "artifact-table",
            message: "기능 목록을 표로 정리해줘",
            expectedRoute: .artifactWorkflow,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            shouldRequireApproval: false,
            notes: "표 기반 파일 생성"
        ),
        .init(
            id: "direct-chat",
            message: "오늘 기분 어때?",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "일반 대화"
        ),
        .init(
            id: "team-discussion",
            message: "이 기능 방향을 팀원들이 검토해줘",
            expectedRoute: .teamDiscussion,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "팀 토론"
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
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "향후 Google Calendar briefing route 후보"
        ),
        .init(
            id: "future-gmail-metadata",
            message: "새 메일 몇 통 왔어?",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "향후 Gmail metadata briefing route 후보"
        ),
        .init(
            id: "future-gmail-summary",
            message: "중요한 메일만 요약해줘",
            expectedRoute: .directChat,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: false,
            notes: "향후 Gmail summary route 후보"
        ),
        .init(
            id: "blocked-delete",
            message: "workspace 파일 삭제해줘",
            expectedRoute: .blockedHighRiskSkill,
            expectedSkillID: nil,
            expectedRouteHint: nil,
            shouldRequireApproval: true,
            notes: "삭제 차단"
        ),
        .init(
            id: "delegation-artifact-request",
            message: "보고서랑 체크리스트를 내가 맡길게",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "artifactWorkflow",
            shouldRequireApproval: true,
            notes: "artifact 경계 + 위임"
        ),
        .init(
            id: "delegation-team-discussion",
            message: "기획부터 결과까지 알아서 해줘. 팀 의견도 정리해줘",
            expectedRoute: .delegationAwaitingApproval,
            expectedSkillID: nil,
            expectedRouteHint: "teamDiscussion",
            shouldRequireApproval: true,
            notes: "팀 토론 위임"
        )
    ]

    static func evaluateCase(_ testCase: RouterBurnInCase) -> RouterBurnInResult {
        let actual = classify(message: testCase.message)
        let passed = actual.route == testCase.expectedRoute
            && (testCase.expectedSkillID == nil || testCase.expectedSkillID == actual.skillID)
            && (testCase.expectedRouteHint == nil || testCase.expectedRouteHint == actual.routeHint)
            && actual.requiresApproval == testCase.shouldRequireApproval

        return RouterBurnInResult(
            id: testCase.id,
            passed: passed,
            expected: expectedDescription(for: testCase),
            actual: actualDescription(for: actual),
            notes: testCase.notes
        )
    }

    static func runAll() -> RouterBurnInSummary {
        let results = cases.map(evaluateCase)
        let passed = results.filter(\.passed).count
        let failed = results.count - passed
        return RouterBurnInSummary(total: results.count, passed: passed, failed: failed, failures: results.filter { !$0.passed })
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
            let request = AppLaunchSkillService.extractRequest(from: message, skillType: appLaunchType)
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

        let allMatches = SkillRegistry.shared.matchAllSkills(for: message)
        if let disabled = allMatches.first(where: { !SkillRegistry.shared.isSkillEnabled(id: $0.id) }) {
            return DetectedRoute(route: .disabledSkill, skillID: disabled.id, routeHint: nil, requiresApproval: false)
        }
        if let enabled = SkillRegistry.shared.matchEnabledSkills(for: message).first {
            return DetectedRoute(route: .localSkill, skillID: enabled.id, routeHint: nil, requiresApproval: false)
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
        let nouns = ["보고서", "ppt", "프레젠테이션", "발표자료", "엑셀", "스프레드시트", "파일", "문서", "초안", "체크리스트", "리포트", "표"]
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
            "로그인", "인증", "삭제", "지워", "제거", "해킹", "은행"
        ]
        return keywords.contains { lower.contains($0) }
    }

    private static func expectedDescription(for testCase: RouterBurnInCase) -> String {
        var parts = ["route=\(testCase.expectedRoute.rawValue)"]
        if let skillID = testCase.expectedSkillID { parts.append("skill=\(skillID)") }
        if let routeHint = testCase.expectedRouteHint { parts.append("hint=\(routeHint)") }
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
}
