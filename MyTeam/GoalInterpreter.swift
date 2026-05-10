import Foundation

enum GoalInterpreter {
    static func interpret(_ message: String) -> GoalInterpretation {
        let lower = message.lowercased()

        if containsAny(lower, keywords: dailyBriefingKeywords) {
            return makeGoal(
                preview: message,
                type: .dailyBriefing,
                title: "오늘 브리핑",
                outputs: ["오늘 일정", "새 메일", "중요 메일 후보", "오늘 할 일", "확인 필요 항목"],
                capabilities: [.dailyBriefingPreview, .calendarRead, .mailMetadataRead]
            )
        }

        if containsAny(lower, keywords: connectorSetupKeywords) {
            return makeGoal(
                preview: message,
                type: .connectorSetup,
                title: "연결 준비",
                outputs: ["OAuth 설정", "연결 상태"],
                capabilities: [.userInitiatedOAuth]
            )
        }

        if containsAny(lower, keywords: automaticLoginKeywords) {
            return makeGoal(
                preview: message,
                type: .connectorSetup,
                title: "자동 로그인",
                outputs: ["계정 연결"],
                capabilities: [.automaticLogin],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: destructiveActionKeywords) {
            return makeGoal(
                preview: message,
                type: .unknown,
                title: "차단된 작업",
                outputs: ["자동 실행 차단"],
                capabilities: [.destructiveFileAction],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: appLaunchKeywords) {
            let appName = extractedAppName(from: message)
            return makeGoal(
                preview: message,
                type: .appLaunch,
                title: "앱 출시 문서",
                outputs: ["앱스토어 설명문", "온보딩 문구", "출시 체크리스트", "수익화 점검표"],
                capabilities: [.llmGeneration, .artifactCreation],
                missingInputs: appName == nil ? ["앱 이름"] : [],
                confidence: appName == nil ? .medium : .high,
                requiresClarification: appName == nil
            )
        }

        if containsAny(lower, keywords: privacyTermsKeywords) {
            let serviceNameMissing = extractedAppName(from: message) == nil
            return makeGoal(
                preview: message,
                type: .privacyTerms,
                title: "개인정보처리방침 / 이용약관",
                outputs: ["정책 초안", "심사 전 확인사항"],
                capabilities: [.llmGeneration, .artifactCreation],
                missingInputs: serviceNameMissing ? ["앱 이름 또는 서비스명"] : [],
                confidence: serviceNameMissing ? .medium : .high,
                requiresClarification: serviceNameMissing
            )
        }

        if containsAny(lower, keywords: mailSendKeywords) {
            return makeGoal(
                preview: message,
                type: .mailAction,
                title: "메일 작업",
                outputs: ["메일 초안", "메일 발송"],
                capabilities: [.mailDraft, .mailSend],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: mailSummaryKeywords) {
            return makeGoal(
                preview: message,
                type: .mailBriefing,
                title: "메일 브리핑",
                outputs: ["새 메일 수", "중요 메일 후보", "요약"],
                capabilities: [.mailMetadataRead, .mailSummarize],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: calendarActionKeywords) {
            return makeGoal(
                preview: message,
                type: .calendarAction,
                title: "일정 작업",
                outputs: ["일정 생성", "일정 수정", "일정 삭제"],
                capabilities: [.calendarCreate, .calendarModify],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: calendarBriefingKeywords) {
            return makeGoal(
                preview: message,
                type: .calendarBriefing,
                title: "캘린더 브리핑",
                outputs: ["오늘 일정", "다가오는 일정"],
                capabilities: [.calendarRead],
                confidence: .high
            )
        }

        if looksLikeGenericDocumentGoal(lower, original: message) {
            return makeGoal(
                preview: message,
                type: .documentWork,
                title: "문서 작업",
                outputs: ["요약", "보고서", "체크리스트", "표", "회의록"],
                capabilities: [.llmGeneration, .artifactCreation],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: documentKeywords) {
            return makeGoal(
                preview: message,
                type: .documentWork,
                title: "문서 작업",
                outputs: ["요약", "보고서", "체크리스트", "표", "회의록"],
                capabilities: [.llmGeneration, .artifactCreation],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: fileCreationKeywords) {
            return makeGoal(
                preview: message,
                type: .fileCreation,
                title: "파일 생성",
                outputs: ["Markdown 파일", "문서 산출물"],
                capabilities: [.artifactCreation],
                confidence: .medium
            )
        }

        if containsAny(lower, keywords: teamDiscussionKeywords) {
            return makeGoal(
                preview: message,
                type: .teamDiscussion,
                title: "팀 협업",
                outputs: ["팀 의견", "검토 결과"],
                capabilities: [.llmGeneration],
                confidence: .high
            )
        }

        if containsAny(lower, keywords: directAnswerKeywords) {
            return makeGoal(
                preview: message,
                type: .directAnswer,
                title: "직접 답변",
                outputs: ["짧은 답변"],
                capabilities: [.answer],
                confidence: .medium
            )
        }

        return makeGoal(
            preview: message,
            type: .unknown,
            title: "요청 해석 중",
            outputs: ["답변", "문서", "파일"],
            capabilities: [.answer],
            confidence: .low
        )
    }

    private static func makeGoal(
        preview: String,
        type: GoalInterpretation.GoalType,
        title: String,
        outputs: [String],
        capabilities: [AssistantCapability],
        missingInputs: [String] = [],
        confidence: GoalInterpretation.Confidence = .medium,
        requiresClarification: Bool = false
    ) -> GoalInterpretation {
        GoalInterpretation(
            id: UUID(),
            userMessagePreview: String(preview.prefix(120)),
            goalType: type,
            title: title,
            inferredOutputs: outputs,
            requiredCapabilities: capabilities,
            missingInputs: missingInputs,
            confidence: confidence,
            requiresClarification: requiresClarification || !missingInputs.isEmpty,
            createdAt: Date()
        )
    }

    private static let dailyBriefingKeywords = [
        "오늘 브리핑",
        "오늘 뭐 있어",
        "오늘 일정",
        "오늘 할 일",
        "업무 브리핑",
        "내 하루 정리"
    ]

    private static let connectorSetupKeywords = [
        "구글 연결",
        "캘린더 연결",
        "구글 캘린더 연결",
        "구글 로그인",
        "oauth",
        "연결할게",
        "연결해줘",
        "연결해",
        "연결해주세요",
        "설정 저장"
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

    private static let automaticLoginKeywords = [
        "자동 로그인",
        "자동으로 로그인",
        "몰래 로그인",
        "계정 접속"
    ]

    private static let mailSendKeywords = [
        "메일 보내",
        "이메일 보내",
        "메일 발송",
        "답장 초안",
        "메일 초안",
        "이메일 초안"
    ]

    private static let mailSummaryKeywords = [
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

    private static let calendarActionKeywords = [
        "일정 만들어",
        "일정 추가",
        "일정 수정",
        "일정 변경",
        "일정 삭제",
        "캘린더 수정",
        "미팅 잡아"
    ]

    private static let calendarBriefingKeywords = [
        "오늘 일정",
        "다가오는 일정",
        "일정 브리핑",
        "회의 일정",
        "스케줄"
    ]

    private static let documentKeywords = [
        "요약",
        "보고서",
        "체크리스트",
        "표로",
        "회의록",
        "액션아이템"
    ]

    private static let fileCreationKeywords = [
        "파일 만들어",
        "파일 생성",
        "파일 작성",
        "문서 만들어",
        "문서 생성",
        "문서 작성",
        "파일로 만들어",
        "markdown",
        "md",
        "artifact",
        "산출물"
    ]

    private static let destructiveActionKeywords = [
        "파일 삭제",
        "파일 지워",
        "파일 제거",
        "일정 삭제",
        "삭제해줘",
        "지워줘",
        "제거해줘",
        "삭제",
        "지워",
        "제거",
        "destroy",
        "remove"
    ]

    private static let teamDiscussionKeywords = [
        "팀",
        "팀원",
        "검토",
        "의견",
        "토론",
        "논의",
        "같이",
        "피드백"
    ]

    private static let directAnswerKeywords = [
        "어때",
        "뭐야",
        "왜",
        "어떻게",
        "알려줘",
        "봐줘",
        "생각해줘"
    ]

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func looksLikeGenericDocumentGoal(_ lower: String, original: String) -> Bool {
        guard lower.contains("정리") || lower.contains("요약") else { return false }
        let contextCues = [
            "문서", "업무용", "자료", "내용", "회의", "보고", "표",
            "체크리스트", "파일로", "붙여넣", "아래 내용", "원문", "초안"
        ]
        if contextCues.contains(where: { lower.contains($0) }) { return true }
        if original.contains("\n") || original.contains("```") { return true }
        if lower.contains("정리") && original.count >= 20 && original.contains(" ") { return true }
        return false
    }

    private static func extractedAppName(from message: String) -> String? {
        let lower = message.lowercased()
        let markers = [
            "앱 이름은",
            "앱명은",
            "서비스명은"
        ]

        for marker in markers {
            if let range = lower.range(of: marker) {
                let tail = message[range.upperBound...]
                let name = tail
                    .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," || $0 == "!" || $0 == "?" || $0 == ":" })
                    .first
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let name, !name.isEmpty { return name }
            }
        }

        for marker in appLaunchKeywords + privacyTermsKeywords {
            if let range = lower.range(of: marker.lowercased()) {
                let prefix = message[..<range.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "·,-.!?"))
                let components = prefix.split { $0.isWhitespace || $0 == "." || $0 == "," }
                if components.count > 0, components.count <= 3, prefix.count <= 24 {
                    let candidate = prefix.replacingOccurrences(of: "앱은", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidate.isEmpty, !candidate.contains("앱스토어"), !candidate.contains("온보딩") {
                        return candidate
                    }
                }
            }
        }

        return nil
    }
}
