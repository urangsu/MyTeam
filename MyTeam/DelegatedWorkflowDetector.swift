import Foundation

enum DelegatedWorkflowDetector {
    private static let requestKeywords = [
        "맡길게",
        "알아서 해줘",
        "끝까지 진행해줘",
        "기획부터 결과까지",
        "처음부터 끝까지",
        "완성해줘",
        "다 만들어줘",
        "전체 진행해줘",
        "내가 허락할게",
        "알아서 만들어줘"
    ]

    private static let approvalKeywords = [
        "응 진행해",
        "진행해",
        "승인",
        "허락",
        "그대로 해",
        "그 범위로 해",
        "오케이",
        "좋아 진행",
        "위임모드 시작"
    ]

    private static let cancelKeywords = [
        "그만",
        "중단",
        "멈춰",
        "취소",
        "위임모드 종료",
        "위임 취소",
        "자동 진행 그만"
    ]

    private static let appLaunchKeywords = [
        "앱스토어 설명문",
        "앱스토어",
        "온보딩",
        "출시 체크리스트",
        "수익화 점검표",
        "랜딩페이지",
        "릴리즈 노트",
        "스크린샷 캡션"
    ]

    private static let privacyTermsKeywords = [
        "개인정보처리방침",
        "이용약관",
        "정책 초안"
    ]

    private static let artifactWorkflowKeywords = [
        "ppt",
        "피피티",
        "엑셀",
        "스프레드시트",
        "파일",
        "문서",
        "초안"
    ]

    private static let universalDocumentKeywords = [
        "요약",
        "보고서",
        "체크리스트",
        "표로",
        "회의록",
        "액션아이템",
        "할 일",
        "todo"
    ]

    static func isDelegationRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        return containsAny(lower, keywords: requestKeywords)
    }

    static func isDelegationApproval(_ message: String) -> Bool {
        let lower = message.lowercased()
        return containsAny(lower, keywords: approvalKeywords)
    }

    static func isDelegationCancel(_ message: String) -> Bool {
        let lower = message.lowercased()
        return containsAny(lower, keywords: cancelKeywords)
    }

    static func inferGoal(from message: String) -> String {
        var cleaned = message
        for keyword in requestKeywords + approvalKeywords + cancelKeywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
        }
        cleaned = cleaned.replacingOccurrences(of: "위임모드", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
        cleaned = cleaned.replacingOccurrences(of: "자동 진행", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
        cleaned = cleaned.replacingOccurrences(of: "맡기", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
        cleaned = cleaned.replacingOccurrences(of: "진행해", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
        cleaned = cleaned.replacingOccurrences(of: "해줘", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)

        let normalized = cleaned
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? "사용자가 요청한 작업" : normalized
    }

    static func inferRequestedScopes(from message: String) -> [DelegationContract.Scope] {
        let lower = message.lowercased()
        var scopes: [DelegationContract.Scope] = []

        if containsAny(lower, keywords: appLaunchKeywords + privacyTermsKeywords + [
            "앱스토어 설명문",
            "온보딩",
            "출시 체크리스트",
            "수익화 점검표",
            "랜딩페이지",
            "릴리즈 노트",
            "스크린샷 캡션"
        ]) {
            scopes.append(.artifactCreation)
            scopes.append(.llmSkill)
        }

        if containsAny(lower, keywords: ["답변", "요약", "설명", "정리", "응답"]) {
            scopes.append(.answerOnly)
        }
        if containsAny(lower, keywords: ["로컬", "local", "스킬", "skill", "글자 수", "문서 내", "내부"]) {
            scopes.append(.localSkill)
        }
        if containsAny(lower, keywords: ["llm", "모델", "추론", "분석", "생성"]) {
            scopes.append(.llmSkill)
        }
        if containsAny(lower, keywords: ["markdown", "md", "문서", "파일", "초안", "artifact", "산출물"] + artifactWorkflowKeywords) || looksLikeGenericDocumentRequest(lower, original: message) {
            scopes.append(.artifactCreation)
        }
        if containsAny(lower, keywords: ["툴", "도구", "브라우저", "웹", "검색", "외부"]) {
            scopes.append(.toolExecution)
        }
        if isMailSendRequest(lower) {
            scopes.append(.externalWrite)
        } else if isReadOnlyMailRequest(lower) {
            scopes.append(.answerOnly)
        }
        if containsAny(lower, keywords: ["결제", "구매", "청구", "가격", "돈"]) {
            scopes.append(.payment)
        }
        if containsAny(lower, keywords: ["로그인", "인증", "계정", "sign in", "signin"]) && !isUserInitiatedConnectorSetup(lower) {
            scopes.append(.login)
        }
        if containsAny(lower, keywords: ["삭제", "지워", "제거", "덮어쓰기", "destroy", "remove"]) {
            scopes.append(.destructive)
        }

        return dedupe(scopes)
    }

    static func normalizedExecutionMessage(from message: String) -> String {
        var cleaned = message
        for keyword in requestKeywords + approvalKeywords + cancelKeywords + ["위임모드", "전체 진행", "자동 진행"] {
            cleaned = cleaned.replacingOccurrences(
                of: keyword,
                with: " ",
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil
            )
        }

        cleaned = cleaned
            .replacingOccurrences(of: "맡겨줘", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
            .replacingOccurrences(of: "알아서", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
            .replacingOccurrences(of: "기획부터 결과까지", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
            .replacingOccurrences(of: "처음부터 끝까지", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
            .replacingOccurrences(of: "전체 진행해줘", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)
            .replacingOccurrences(of: "알아서 해줘", with: " ", options: [.caseInsensitive, .diacriticInsensitive], range: nil)

        let normalized = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let shortened = String(normalized.prefix(480))
        return shortened.isEmpty ? "사용자가 요청한 작업" : shortened
    }

    static func inferRouteHint(from message: String) -> String? {
        let lower = message.lowercased()

        if containsAny(lower, keywords: appLaunchKeywords + ["앱스토어 설명문", "온보딩", "출시 체크리스트", "수익화 점검표"]) {
            return "appLaunchPack"
        }
        if containsAny(lower, keywords: privacyTermsKeywords) {
            return "privacyTerms"
        }
        if containsAny(lower, keywords: universalDocumentKeywords) || looksLikeGenericDocumentRequest(lower, original: message) {
            return "universalDocument"
        }
        if containsAny(lower, keywords: artifactWorkflowKeywords) {
            return "artifactWorkflow"
        }
        return "teamDiscussion"
    }

    static func isReadOnlyMailRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        let readKeywords = [
            "새 메일",
            "메일 몇 통",
            "메일 목록",
            "메일 제목",
            "메일 발신자",
            "메일 요약",
            "메일 본문",
            "내용 읽어",
            "중요한 메일",
            "메일이랑 일정"
        ]
        guard containsAny(lower, keywords: readKeywords) else { return false }
        return !isMailSendRequest(lower)
    }

    static func isUserInitiatedConnectorSetup(_ message: String) -> Bool {
        let lower = message.lowercased()
        return containsAny(lower, keywords: [
            "구글 연결",
            "캘린더 연결",
            "oauth",
            "연결할게",
            "설정 저장",
            "사용자가 연결"
        ])
    }

    static func isMailSendRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        let keywords = [
            "메일 보내",
            "이메일 보내",
            "메일 발송",
            "답장 보내",
            "전송해",
            "공유해"
        ]
        return containsAny(lower, keywords: keywords) || (
            containsAny(lower, keywords: ["메일", "이메일"]) &&
            containsAny(lower, keywords: ["보내", "발송", "전송", "공유"])
        )
    }

    static func looksLikeGenericDocumentRequest(_ lower: String, original: String) -> Bool {
        guard lower.contains("정리") || lower.contains("요약") else { return false }

        let contextKeywords = [
            "문서", "업무용", "자료", "내용", "회의", "보고", "표",
            "체크리스트", "파일로", "붙여넣", "아래 내용", "원문", "초안"
        ]
        if contextKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        if original.contains("\n") || original.contains("```") {
            return true
        }
        if lower.contains("정리") && original.count >= 20 {
            return true
        }
        return false
    }

    static func buildExecutionRequest(
        roomID: UUID,
        contract: DelegationContract,
        message: String
    ) -> DelegatedExecutionRequest {
        DelegatedExecutionRequest(
            id: UUID(),
            roomID: roomID,
            contractID: contract.id,
            originalMessagePreview: String(message.prefix(120)),
            normalizedExecutionMessage: normalizedExecutionMessage(from: message),
            routeHint: inferRouteHint(from: message),
            status: .pendingApproval,
            createdAt: Date()
        )
    }

    static func buildContract(roomID: UUID, message: String) -> DelegationContract {
        let goal = inferGoal(from: message)
        let requestedScopes = inferRequestedScopes(from: message)
        let approvalDecisions = ApprovalPolicy.decision(for: requestedScopes)
        let blockedScopes = requestedScopes.enumerated().compactMap { index, scope in
            if case .blocked = approvalDecisions[index] { return scope }
            return nil
        }
        let reapprovalScopes = requestedScopes.enumerated().compactMap { index, scope in
            if case .requiresApproval = approvalDecisions[index] { return scope }
            return nil
        }

        var expectedOutputs = ["자연어 응답 초안"]
        if requestedScopes.contains(.artifactCreation) {
            expectedOutputs.append("Markdown 산출물")
        }
        if requestedScopes.contains(.localSkill) {
            expectedOutputs.append("로컬 스킬 결과")
        }
        if requestedScopes.contains(.llmSkill) {
            expectedOutputs.append("LLM 결과 초안")
        }

        return DelegationContract(
            id: UUID(),
            roomID: roomID,
            userMessagePreview: String(message.prefix(120)),
            goal: goal,
            allowedScopes: [.answerOnly, .localSkill, .llmSkill, .artifactCreation],
            blockedScopes: dedupe(blockedScopes),
            requiresReapprovalScopes: dedupe(reapprovalScopes),
            expectedOutputs: dedupe(expectedOutputs),
            status: .awaitingApproval,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        )
    }

    static func buildPlan(for contract: DelegationContract) -> DelegatedWorkflowPlan {
        var steps: [DelegatedWorkflowPlan.Step] = [
            step(.understand, "요청 이해", "위임 의도와 작업 목표를 정리합니다.", expectedOutput: "작업 목표 요약", requiresApproval: false),
            step(.plan, "실행 계획", "허용 범위와 제한 범위를 나눠 계획합니다.", expectedOutput: "실행 계획", requiresApproval: false)
        ]

        if !contract.requiresReapprovalScopes.isEmpty {
            steps.append(step(.requiresApproval, "추가 승인 필요", "외부 전송·도구 실행처럼 다시 확인이 필요한 범위를 표시합니다.", expectedOutput: "승인 필요 항목", requiresApproval: true))
        }

        if !contract.blockedScopes.isEmpty {
            steps.append(step(.blocked, "차단 항목 확인", "결제·로그인·삭제처럼 자동 진행이 막힌 범위를 표시합니다.", expectedOutput: "차단 항목", requiresApproval: true))
        }

        if contract.expectedOutputs.contains(where: { $0.localizedCaseInsensitiveContains("Markdown") }) {
            steps.append(step(.createArtifact, "문서 생성", "요청에 맞는 Markdown 초안을 준비합니다.", expectedOutput: "Markdown artifact", requiresApproval: false))
        } else {
            steps.append(step(.generateText, "답변 생성", "요청 내용을 바탕으로 초안을 준비합니다.", expectedOutput: "텍스트 응답", requiresApproval: false))
        }

        steps.append(step(.verify, "검토", "실제 실행 전 결과의 범위와 위험을 한 번 더 확인합니다.", expectedOutput: "검토 결과", requiresApproval: false))
        steps.append(step(.summarize, "요약", "사용자가 바로 이해할 수 있는 안내로 정리합니다.", expectedOutput: "최종 요약", requiresApproval: false))

        return DelegatedWorkflowPlan(
            id: UUID(),
            contractID: contract.id,
            roomID: contract.roomID,
            title: contract.goal,
            steps: steps,
            expectedArtifacts: contract.expectedOutputs,
            riskSummary: riskSummary(for: contract),
            createdAt: Date()
        )
    }

    private static func step(
        _ kind: DelegatedWorkflowPlan.Step.Kind,
        _ title: String,
        _ detail: String,
        expectedOutput: String?,
        requiresApproval: Bool
    ) -> DelegatedWorkflowPlan.Step {
        DelegatedWorkflowPlan.Step(
            id: UUID(),
            kind: kind,
            title: title,
            detail: detail,
            expectedOutput: expectedOutput,
            requiresApproval: requiresApproval
        )
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func dedupe<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func riskSummary(for contract: DelegationContract) -> String {
        var parts: [String] = []
        if !contract.requiresReapprovalScopes.isEmpty {
            parts.append("외부 전송/도구 실행은 승인 필요")
        }
        if !contract.blockedScopes.isEmpty {
            parts.append("결제/로그인/삭제는 차단")
        }
        if parts.isEmpty {
            parts.append("자동 허용 범위만 포함")
        }
        return parts.joined(separator: " · ")
    }
}
