import Foundation

enum NaturalWorkConfidence: String, Sendable, Equatable {
    case high
    case medium
    case low
}

enum NaturalIntent: String, Sendable, Equatable {
    case companyOverview
    case stockPrice
    case disclosure
    case companyFinance
    case news
    case weather
    case law
    case documentDraft
    case meetingMinutes
    case budgetReview
    case closingVarianceAnalysis
    case tableCleanupPlan
    case schedulePreparation
    case fileSummary
    case evidenceCheck
}

enum NaturalEntity: Sendable, Equatable {
    case companyName(String)
    case stockCode(String)
    case corpCode(String)
    case region(String)
    case lawName(String)
    case dateExpression(String)
    case documentType(String)
}

enum NaturalWorkType: String, Sendable, Equatable {
    case companyBriefing
    case meetingMinutes
    case reportDraft
    case budgetReview
    case closingVarianceAnalysis
    case tableCleanupPlan
    case lawIssueReview
    case schedulePreparation
    case newsBriefing
    case disclosureReview
    case evidenceCheck
    case fileSummary
}

enum NaturalWorkCompositionStyle: String, Sendable, Equatable {
    case compositeBriefing
    case singleTopic
    case draft
}

enum NaturalStepFailurePolicy: String, Sendable, Equatable {
    case required
    case partial
}

struct CompanyIdentity: Sendable, Equatable {
    let displayName: String
    let stockCode: String?
    let dartCorpCode: String?
    let source: String
}

struct NaturalWorkContext: Sendable {
    let roomID: UUID?
    let activeArtifactID: String?
    let recentArtifacts: [IndexedArtifact]
    let pendingAttachments: [ChatAttachment]
    let recentMessageTexts: [String]
    let lastCompanyIdentity: CompanyIdentity?
    let lastWorkType: NaturalWorkType?
    let userLocation: String?

    static let empty = NaturalWorkContext(
        roomID: nil,
        activeArtifactID: nil,
        recentArtifacts: [],
        pendingAttachments: [],
        recentMessageTexts: [],
        lastCompanyIdentity: nil,
        lastWorkType: nil,
        userLocation: nil
    )

    var attachmentText: String {
        pendingAttachments
            .compactMap(\.textContent)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var recentText: String {
        recentMessageTexts
            .suffix(6)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NaturalWorkRequest: Sendable, Equatable {
    let originalText: String
    let entities: [NaturalEntity]
    let intents: [NaturalIntent]
    let confidence: NaturalWorkConfidence
    let clarificationQuestion: String?
}

struct NaturalWorkPlan: Sendable, Equatable {
    let request: NaturalWorkRequest
    let workType: NaturalWorkType
    let title: String
    let userFacingSummary: String
    let steps: [NaturalToolStep]
    let compositionStyle: NaturalWorkCompositionStyle
    let userNotice: String?
    let preflightMissingSections: [NaturalMissingSection]
}

struct NaturalToolStep: Sendable, Equatable, Identifiable {
    let id: String
    let toolID: String
    let input: MyTeamToolInput
    let fallbackInputs: [MyTeamToolInput]
    let required: Bool
    let sectionTitle: String
    let failurePolicy: NaturalStepFailurePolicy

    init(
        id: String,
        toolID: String,
        input: MyTeamToolInput,
        fallbackInputs: [MyTeamToolInput] = [],
        required: Bool = false,
        sectionTitle: String,
        failurePolicy: NaturalStepFailurePolicy = .partial
    ) {
        self.id = id
        self.toolID = toolID
        self.input = input
        self.fallbackInputs = fallbackInputs
        self.required = required
        self.sectionTitle = sectionTitle
        self.failurePolicy = failurePolicy
    }
}

struct NaturalResultSection: Sendable, Equatable {
    let title: String
    let summary: String
    let body: String?
    let sourceLabel: String?
    let sourceLinks: [URL]
}

struct NaturalMissingSection: Sendable, Equatable {
    let title: String
    let reason: String
    let nextAction: String?
}

struct NaturalWorkResult: Sendable, Equatable {
    let planTitle: String
    let sections: [NaturalResultSection]
    let missingSections: [NaturalMissingSection]
    let notices: [String]
    let artifactTitle: String
    let artifactMarkdown: String
}

struct NaturalStepExecution: Sendable, Equatable {
    let step: NaturalToolStep
    let descriptor: MyTeamToolDescriptor?
    let state: ToolExecutionState
}

enum CompanyIdentityResolver {
    static func resolve(from text: String) -> CompanyIdentity? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let corpCode = firstMatch(#"\b\d{8}\b"#, in: trimmed) {
            return CompanyIdentity(
                displayName: corpCode,
                stockCode: nil,
                dartCorpCode: corpCode,
                source: "dartCorpCode"
            )
        }
        if let stockCode = firstMatch(#"\b\d{6}\b"#, in: trimmed) {
            return CompanyIdentity(
                displayName: stockCode,
                stockCode: stockCode,
                dartCorpCode: nil,
                source: "stockCode"
            )
        }
        guard let name = companyNameCandidate(from: trimmed), !name.isEmpty else { return nil }
        return CompanyIdentity(
            displayName: name,
            stockCode: nil,
            dartCorpCode: nil,
            source: "companyName"
        )
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func companyNameCandidate(from text: String) -> String? {
        var normalized = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "·", with: " ")

        let stopWords = [
            "오늘 볼만한 내용", "공시사항", "재무상황", "재무제표", "손익계산서", "재무상태표",
            "주가", "주식", "시세", "가격", "공시", "DART", "다트", "재무", "요약재무",
            "실적", "뉴스", "최근 소식", "이슈", "알려줘", "알려", "보여줘", "봐줘", "어때",
            "정리해줘", "정리", "조회해줘", "조회", "확인", "분석", "그리고", "랑", "와", "과",
            "도", "좀", "해줘", "회사", "관련", "내용"
        ]
        for word in stopWords {
            normalized = normalized.replacingOccurrences(of: word, with: " ", options: [.caseInsensitive])
        }

        let tokens = normalized
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { token in
                token.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) == nil
            }
        guard let first = tokens.first else { return nil }
        let candidate = first.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count >= 2 else { return nil }
        let blocked = ["나", "내", "우리", "이거", "저거", "뉴스", "캘린더", "날씨"]
        return blocked.contains(candidate) ? nil : candidate
    }
}

enum NaturalWorkRouter {
    static func plan(for message: String) -> NaturalWorkPlan? {
        plan(for: message, context: .empty)
    }

    static func plan(for message: String, context: NaturalWorkContext) -> NaturalWorkPlan? {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let lower = normalized.lowercased()

        if isDocumentDraftRequest(lower) || isFollowUpRewriteRequest(lower) {
            return documentDraftPlan(for: normalized, context: context)
        }
        if isMeetingMinutesRequest(lower) {
            return meetingMinutesPlan(for: normalized, context: context)
        }
        if isBudgetReviewRequest(lower) {
            return spreadsheetReviewPlan(
                for: normalized,
                context: context,
                workType: .budgetReview,
                intent: .budgetReview,
                title: "예산 검토",
                summary: "예산 자료에서 증감, 누락, 초과 항목을 확인 중입니다.",
                sectionTitle: "예산 검토"
            )
        }
        if isClosingVarianceRequest(lower) {
            return spreadsheetReviewPlan(
                for: normalized,
                context: context,
                workType: .closingVarianceAnalysis,
                intent: .closingVarianceAnalysis,
                title: "결산 차이 검토",
                summary: "결산 자료에서 계획 대비 차이와 확인 항목을 찾는 중입니다.",
                sectionTitle: "결산 차이"
            )
        }
        if isTableCleanupRequest(lower) {
            return spreadsheetReviewPlan(
                for: normalized,
                context: context,
                workType: .tableCleanupPlan,
                intent: .tableCleanupPlan,
                title: "표 정리 계획",
                summary: "표의 중복, 누락, 검산 항목을 확인 중입니다.",
                sectionTitle: "표 정리"
            )
        }
        if isScheduleRequest(lower) {
            return schedulePlan(for: normalized)
        }
        if isFileSummaryRequest(lower) {
            return fileSummaryPlan(for: normalized, context: context)
        }
        if isWeatherRequest(lower) {
            return weatherPlan(for: normalized)
        }
        if isLawRequest(lower) {
            return lawPlan(for: normalized)
        }
        if isNewsRequest(lower), !hasCompanyCompositeCue(lower) {
            return newsPlan(for: normalized)
        }
        if isCompanyMarketRequest(lower), let identity = CompanyIdentityResolver.resolve(from: normalized) {
            return companyPlan(for: normalized, identity: identity, lower: lower)
        }
        if looksLikeCompanyOverview(lower), let identity = CompanyIdentityResolver.resolve(from: normalized) {
            return companyOverviewPlan(originalText: normalized, identity: identity)
        }
        return nil
    }

    static func runningMarkdown(for plan: NaturalWorkPlan) -> String {
        """
        ### 요청을 확인하고 있습니다

        \(plan.userFacingSummary)
        """
    }

    private static func companyPlan(
        for originalText: String,
        identity: CompanyIdentity,
        lower: String
    ) -> NaturalWorkPlan {
        var intents: [NaturalIntent] = []
        if containsAny(lower, ["주가", "주식", "시세", "가격"]) { intents.append(.stockPrice) }
        if containsAny(lower, ["공시", "dart", "다트"]) { intents.append(.disclosure) }
        if containsAny(lower, ["재무", "재무상황", "재무제표", "실적", "손익계산서", "재무상태표"]) { intents.append(.companyFinance) }
        if containsAny(lower, ["뉴스", "최근 소식", "이슈"]) { intents.append(.news) }
        if intents.isEmpty || looksLikeCompanyOverview(lower) {
            return companyOverviewPlan(originalText: originalText, identity: identity)
        }
        return plan(
            originalText: originalText,
            identity: identity,
            intents: intents,
            title: "\(identity.displayName) 업무 조회",
            summary: "\(identity.displayName)을 요청한 항목으로 나누어 확인 중입니다.",
            style: .compositeBriefing
        )
    }

    private static func companyOverviewPlan(originalText: String, identity: CompanyIdentity) -> NaturalWorkPlan {
        plan(
            originalText: originalText,
            identity: identity,
            intents: [.companyOverview, .stockPrice, .disclosure, .companyFinance, .news],
            title: "\(identity.displayName) 회사 참고 브리핑",
            summary: "\(identity.displayName)을 시세, 공시, 재무, 뉴스 기준으로 확인 중입니다.",
            style: .compositeBriefing
        )
    }

    private static func plan(
        originalText: String,
        identity: CompanyIdentity,
        intents: [NaturalIntent],
        title: String,
        summary: String,
        style: NaturalWorkCompositionStyle
    ) -> NaturalWorkPlan {
        let currentYear = Calendar.current.component(.year, from: Date()) - 1
        var steps: [NaturalToolStep] = []
        let companyQuery = identity.stockCode ?? identity.displayName

        if intents.contains(.companyOverview) || intents.contains(.stockPrice) {
            steps.append(step(
                id: "stock-price",
                toolID: "finance.krx.stockPrice",
                query: companyQuery,
                sectionTitle: "기준일 시세"
            ))
            steps.append(step(
                id: "stock-index",
                toolID: "finance.krx.index",
                query: "코스피",
                sectionTitle: "시장 지수 맥락"
            ))
        }
        if intents.contains(.companyOverview) || intents.contains(.disclosure) {
            let dartQuery = identity.dartCorpCode ?? identity.displayName
            steps.append(step(
                id: "disclosures",
                toolID: "dart.disclosures.search",
                query: dartQuery,
                sectionTitle: "최근 공시",
                daysBack: 30
            ))
        }
        if intents.contains(.companyOverview) || intents.contains(.companyFinance) {
            let primary = MyTeamToolInput(query: "\(companyQuery) \(currentYear)", displayCount: 10)
            let fallbacks = [
                MyTeamToolInput(query: "\(companyQuery) \(currentYear - 1)", displayCount: 10),
                MyTeamToolInput(query: "\(companyQuery) \(currentYear - 2)", displayCount: 10)
            ]
            steps.append(NaturalToolStep(
                id: "company-finance",
                toolID: "finance.company.statement",
                input: primary,
                fallbackInputs: fallbacks,
                required: false,
                sectionTitle: "재무 요약"
            ))
        }
        if intents.contains(.companyOverview) || intents.contains(.news) {
            steps.append(step(
                id: "news",
                toolID: "news.search",
                query: identity.displayName,
                sectionTitle: "뉴스",
                displayCount: 5
            ))
        }

        return NaturalWorkPlan(
            request: NaturalWorkRequest(
                originalText: originalText,
                entities: entityList(for: identity),
                intents: intents,
                confidence: .high,
                clarificationQuestion: nil
            ),
            workType: workType(for: intents),
            title: title,
            userFacingSummary: summary,
            steps: steps,
            compositionStyle: style,
            userNotice: "금융 정보는 기준일 공공데이터이며 실시간 시세나 투자 조언이 아닙니다.",
            preflightMissingSections: []
        )
    }

    private static func newsPlan(for text: String) -> NaturalWorkPlan {
        let query = cleaned(text, removing: ["뉴스", "검색", "찾아줘", "조회", "브리핑", "최신"], fallback: "경제")
        return singleStepPlan(
            originalText: text,
            title: "\(query) 뉴스 브리핑",
            summary: "\(query) 관련 뉴스 검색 결과를 확인 중입니다.",
            intent: .news,
            toolID: "news.search",
            query: query,
            sectionTitle: "뉴스",
            displayCount: 5,
            notice: "뉴스 검색 결과의 제목과 설명을 기준으로 정리합니다."
        )
    }

    private static func weatherPlan(for text: String) -> NaturalWorkPlan {
        let query = cleaned(text, removing: ["출장", "외근", "현장작업", "날씨", "오늘", "괜찮아", "알려줘", "봐줘"], fallback: "서울")
        return singleStepPlan(
            originalText: text,
            title: "\(query) 날씨 확인",
            summary: "\(query) 날씨를 확인 중입니다.",
            intent: .weather,
            toolID: "weather.current",
            query: query,
            sectionTitle: "날씨",
            notice: nil
        )
    }

    private static func lawPlan(for text: String) -> NaturalWorkPlan {
        let query = cleaned(text, removing: ["법령", "법률", "조문", "검색", "찾아줘", "조회", "관련해서", "뭘", "봐야", "해"], fallback: "근로기준법")
        return singleStepPlan(
            originalText: text,
            title: "\(query) 법령 확인",
            summary: "\(query) 관련 공식 법령 정보를 확인 중입니다.",
            intent: .law,
            toolID: "law.search",
            query: query,
            sectionTitle: "법령",
            notice: "이 결과는 법령 검색 결과이며 법률 자문이 아닙니다."
        )
    }

    private static func documentDraftPlan(for text: String, context: NaturalWorkContext = .empty) -> NaturalWorkPlan {
        let source = bestSourceText(for: text, context: context)
        return singleStepPlan(
            originalText: text,
            title: "문서 초안",
            summary: "요청한 문서 표현을 정리 중입니다.",
            intent: .documentDraft,
            toolID: "document.rewrite",
            query: source,
            sectionTitle: "문서 초안",
            notice: nil,
            style: .draft,
            explicitWorkType: .reportDraft
        )
    }

    private static func meetingMinutesPlan(for text: String, context: NaturalWorkContext) -> NaturalWorkPlan {
        let source = bestSourceText(for: text, context: context)
        guard hasUsableSource(source, originalText: text) else {
            return missingInputPlan(
                originalText: text,
                workType: .meetingMinutes,
                intent: .meetingMinutes,
                title: "회의록 정리",
                summary: "회의 내용이나 녹취록을 붙여 넣으면 결정사항, 담당자, 기한을 정리할 수 있습니다.",
                missingTitle: "회의 내용",
                reason: "정리할 회의 내용이나 첨부 자료가 필요합니다.",
                nextAction: "회의 메모, 녹취록 텍스트, 회의 파일을 첨부하거나 붙여 넣으세요."
            )
        }
        return singleStepPlan(
            originalText: text,
            title: "회의록 정리",
            summary: "회의 내용에서 결정사항, 지시사항, 담당자, 기한을 추출 중입니다.",
            intent: .meetingMinutes,
            toolID: "document.meetingMinutes",
            query: source,
            sectionTitle: "회의록",
            notice: nil,
            style: .draft,
            explicitWorkType: .meetingMinutes
        )
    }

    private static func spreadsheetReviewPlan(
        for text: String,
        context: NaturalWorkContext,
        workType: NaturalWorkType,
        intent: NaturalIntent,
        title: String,
        summary: String,
        sectionTitle: String
    ) -> NaturalWorkPlan {
        let source = bestSourceText(for: text, context: context)
        guard hasTabularCue(source) || hasAttachmentOrRecentContext(context) else {
            return missingInputPlan(
                originalText: text,
                workType: workType,
                intent: intent,
                title: title,
                summary: "검토할 표나 스프레드시트 내용을 붙여 넣으면 확인 항목을 정리할 수 있습니다.",
                missingTitle: "표 또는 스프레드시트 내용",
                reason: "검토할 표 데이터가 필요합니다.",
                nextAction: "표를 붙여 넣거나 Excel/CSV/Google Sheets 내용을 첨부하세요."
            )
        }
        return singleStepPlan(
            originalText: text,
            title: title,
            summary: summary,
            intent: intent,
            toolID: "spreadsheet.postprocess",
            query: source,
            sectionTitle: sectionTitle,
            notice: "파일을 직접 덮어쓰지 않고 정리 계획과 검산 기준을 만듭니다.",
            style: .draft,
            explicitWorkType: workType
        )
    }

    private static func schedulePlan(for text: String) -> NaturalWorkPlan {
        singleStepPlan(
            originalText: text,
            title: "일정 확인",
            summary: "오늘 일정과 준비할 항목을 확인 중입니다.",
            intent: .schedulePreparation,
            toolID: "calendar.events.today",
            query: text,
            sectionTitle: "일정",
            notice: nil,
            explicitWorkType: .schedulePreparation
        )
    }

    private static func fileSummaryPlan(for text: String, context: NaturalWorkContext) -> NaturalWorkPlan {
        let source = bestSourceText(for: text, context: context)
        guard hasUsableSource(source, originalText: text) || hasAttachmentOrRecentContext(context) else {
            return missingInputPlan(
                originalText: text,
                workType: .fileSummary,
                intent: .fileSummary,
                title: "자료 요약",
                summary: "요약할 파일이나 자료를 첨부하면 핵심 내용을 정리할 수 있습니다.",
                missingTitle: "요약할 자료",
                reason: "요약할 첨부 파일이나 본문이 필요합니다.",
                nextAction: "문서, PDF, 텍스트 자료를 첨부하거나 내용을 붙여 넣으세요."
            )
        }
        return singleStepPlan(
            originalText: text,
            title: "자료 요약",
            summary: "자료에서 핵심 내용과 확인할 항목을 정리 중입니다.",
            intent: .fileSummary,
            toolID: "document.rewrite",
            query: source,
            sectionTitle: "자료 요약",
            notice: nil,
            style: .draft,
            explicitWorkType: .fileSummary
        )
    }

    private static func singleStepPlan(
        originalText: String,
        title: String,
        summary: String,
        intent: NaturalIntent,
        toolID: String,
        query: String,
        sectionTitle: String,
        displayCount: Int? = nil,
        notice: String?,
        style: NaturalWorkCompositionStyle = .singleTopic,
        explicitWorkType: NaturalWorkType? = nil
    ) -> NaturalWorkPlan {
        NaturalWorkPlan(
            request: NaturalWorkRequest(
                originalText: originalText,
                entities: [],
                intents: [intent],
                confidence: .high,
                clarificationQuestion: nil
            ),
            workType: explicitWorkType ?? workType(for: [intent]),
            title: title,
            userFacingSummary: summary,
            steps: [
                step(
                    id: intent.rawValue,
                    toolID: toolID,
                    query: query,
                    sectionTitle: sectionTitle,
                    displayCount: displayCount
                )
            ],
            compositionStyle: style,
            userNotice: notice,
            preflightMissingSections: []
        )
    }

    private static func missingInputPlan(
        originalText: String,
        workType: NaturalWorkType,
        intent: NaturalIntent,
        title: String,
        summary: String,
        missingTitle: String,
        reason: String,
        nextAction: String
    ) -> NaturalWorkPlan {
        NaturalWorkPlan(
            request: NaturalWorkRequest(
                originalText: originalText,
                entities: [],
                intents: [intent],
                confidence: .medium,
                clarificationQuestion: nextAction
            ),
            workType: workType,
            title: title,
            userFacingSummary: summary,
            steps: [],
            compositionStyle: .draft,
            userNotice: nil,
            preflightMissingSections: [
                NaturalMissingSection(
                    title: missingTitle,
                    reason: reason,
                    nextAction: nextAction
                )
            ]
        )
    }

    private static func step(
        id: String,
        toolID: String,
        query: String,
        sectionTitle: String,
        daysBack: Int? = nil,
        displayCount: Int? = nil
    ) -> NaturalToolStep {
        NaturalToolStep(
            id: id,
            toolID: toolID,
            input: MyTeamToolInput(
                query: query,
                daysBack: daysBack,
                displayCount: displayCount
            ),
            sectionTitle: sectionTitle
        )
    }

    private static func entityList(for identity: CompanyIdentity) -> [NaturalEntity] {
        if let stockCode = identity.stockCode { return [.stockCode(stockCode)] }
        if let dartCorpCode = identity.dartCorpCode { return [.corpCode(dartCorpCode)] }
        return [.companyName(identity.displayName)]
    }

    private static func isCompanyMarketRequest(_ lower: String) -> Bool {
        containsAny(lower, [
            "주가", "주식", "시세", "가격", "공시", "공시사항", "dart", "다트",
            "재무", "재무상황", "재무제표", "실적", "손익계산서", "재무상태표",
            "최근 소식", "이슈", "뉴스"
        ])
    }

    private static func hasCompanyCompositeCue(_ lower: String) -> Bool {
        containsAny(lower, [
            "주가", "주식", "시세", "가격", "공시", "공시사항", "dart", "다트",
            "재무", "재무상황", "재무제표", "실적", "손익계산서", "재무상태표"
        ])
    }

    private static func looksLikeCompanyOverview(_ lower: String) -> Bool {
        containsAny(lower, ["알려줘", "봐줘", "어때", "오늘 볼만한", "정리해줘"]) &&
        !containsAny(lower, ["날씨", "법령", "조문", "캘린더", "회의록"])
    }

    private static func isNewsRequest(_ lower: String) -> Bool {
        containsAny(lower, ["뉴스 검색", "뉴스 찾아", "뉴스 조회", "최신 뉴스", "뉴스 브리핑"]) ||
        (lower.contains("뉴스") && !containsAny(lower, ["기사처럼", "문장처럼", "형식으로", "써줘"]))
    }

    private static func isWeatherRequest(_ lower: String) -> Bool {
        lower.contains("날씨") &&
        !containsAny(lower, ["문장", "카피", "기사", "형식"])
    }

    private static func isLawRequest(_ lower: String) -> Bool {
        containsAny(lower, ["법령", "법률", "조문", "근로기준법", "주52시간", "연차", "산안법", "위법", "합법"]) &&
        !containsAny(lower, ["법적으로 자연스럽게", "법적으로 부드럽게", "법적으로 써줘"])
    }

    private static func isDocumentDraftRequest(_ lower: String) -> Bool {
        containsAny(lower, [
            "뉴스 기사처럼", "캘린더 형식", "공시 양식처럼", "주가처럼",
            "문서처럼", "문장처럼", "문체", "써줘", "보고문구", "보고자료",
            "임원 보고", "주주사 보고", "검토 의견", "짧게 써줘"
        ])
    }

    private static func isFollowUpRewriteRequest(_ lower: String) -> Bool {
        containsAny(lower, ["짧게 바꿔", "임원용", "표로 만들어", "체크리스트로", "문구 바꿔"])
    }

    private static func isMeetingMinutesRequest(_ lower: String) -> Bool {
        containsAny(lower, ["회의록", "녹취록", "회의 내용", "지시사항", "결정사항", "담당자", "기한"]) &&
        !containsAny(lower, ["회의록처럼", "회의록 양식"])
    }

    private static func isBudgetReviewRequest(_ lower: String) -> Bool {
        containsAny(lower, ["예산", "예실", "부서별 예산", "계정", "전년 대비", "초과", "누락"])
    }

    private static func isClosingVarianceRequest(_ lower: String) -> Bool {
        containsAny(lower, ["결산", "마감", "계획 대비", "목표 대비", "재고영향", "원가", "매출", "비용"])
    }

    private static func isTableCleanupRequest(_ lower: String) -> Bool {
        containsAny(lower, ["표 정리", "엑셀 정리", "이 표 봐줘", "중복", "검산"])
    }

    private static func isScheduleRequest(_ lower: String) -> Bool {
        containsAny(lower, ["오늘 일정", "내일 일정", "회의 준비", "캘린더 확인", "일정 봐줘"]) &&
        !containsAny(lower, ["캘린더 형식", "캘린더처럼"])
    }

    private static func isFileSummaryRequest(_ lower: String) -> Bool {
        containsAny(lower, ["이 파일", "첨부파일", "자료 요약", "중요한 것", "핵심만"])
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func cleaned(_ text: String, removing tokens: [String], fallback: String) -> String {
        var result = text
        for token in tokens {
            result = result.replacingOccurrences(of: token, with: " ", options: [.caseInsensitive])
        }
        result = result
            .replacingOccurrences(of: "해줘", with: " ")
            .replacingOccurrences(of: "알려줘", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }

    private static func bestSourceText(for text: String, context: NaturalWorkContext) -> String {
        let attachmentText = context.attachmentText
        if !attachmentText.isEmpty {
            return "\(text)\n\n\(attachmentText)"
        }
        if !context.recentText.isEmpty && isFollowUpRewriteRequest(text.lowercased()) {
            return "\(text)\n\n최근 대화:\n\(context.recentText)"
        }
        return text
    }

    private static func hasUsableSource(_ source: String, originalText: String) -> Bool {
        let sourceTrimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalTrimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sourceTrimmed.count > originalTrimmed.count + 20 || sourceTrimmed.count > 120
    }

    private static func hasAttachmentOrRecentContext(_ context: NaturalWorkContext) -> Bool {
        !context.pendingAttachments.isEmpty || context.recentText.count > 120
    }

    private static func hasTabularCue(_ text: String) -> Bool {
        text.contains("\t") ||
        text.split(separator: "\n").filter { $0.contains(",") || $0.contains("|") }.count >= 2
    }

    private static func workType(for intents: [NaturalIntent]) -> NaturalWorkType {
        if intents.contains(.companyOverview) { return .companyBriefing }
        if intents.contains(.stockPrice) { return .companyBriefing }
        if intents.contains(.disclosure) { return .disclosureReview }
        if intents.contains(.companyFinance) { return .companyBriefing }
        if intents.contains(.news) { return .newsBriefing }
        if intents.contains(.weather) { return .schedulePreparation }
        if intents.contains(.law) { return .lawIssueReview }
        if intents.contains(.meetingMinutes) { return .meetingMinutes }
        if intents.contains(.budgetReview) { return .budgetReview }
        if intents.contains(.closingVarianceAnalysis) { return .closingVarianceAnalysis }
        if intents.contains(.tableCleanupPlan) { return .tableCleanupPlan }
        if intents.contains(.schedulePreparation) { return .schedulePreparation }
        if intents.contains(.fileSummary) { return .fileSummary }
        if intents.contains(.evidenceCheck) { return .evidenceCheck }
        return .reportDraft
    }
}

enum NaturalWorkPlanExecutor {
    static func execute(_ plan: NaturalWorkPlan, path: ToolExecutionPath) async -> NaturalWorkResult {
        var executions: [NaturalStepExecution] = []
        await withTaskGroup(of: (Int, NaturalStepExecution).self) { group in
            for (index, step) in plan.steps.enumerated() {
                group.addTask(priority: .userInitiated) {
                    (index, await execute(step, path: path))
                }
            }
            for await pair in group {
                executions.append(pair.1)
            }
        }
        executions.sort { lhs, rhs in
            let left = plan.steps.firstIndex(where: { $0.id == lhs.step.id }) ?? 0
            let right = plan.steps.firstIndex(where: { $0.id == rhs.step.id }) ?? 0
            return left < right
        }
        return NaturalResultComposer.compose(plan: plan, executions: executions)
    }

    private static func execute(_ step: NaturalToolStep, path: ToolExecutionPath) async -> NaturalStepExecution {
        guard let descriptor = MyTeamToolRegistry.descriptor(id: step.toolID) else {
            return NaturalStepExecution(
                step: step,
                descriptor: nil,
                state: .unavailable("이 항목은 아직 준비 중입니다.")
            )
        }

        let readiness = await ToolExecutionRouter.shared.readiness(for: descriptor)
        guard readiness.isRunnable else {
            return NaturalStepExecution(step: step, descriptor: descriptor, state: readiness)
        }

        var state = await ToolExecutionRouter.shared.run(
            descriptor,
            input: step.input,
            bypassApproval: false,
            path: path,
            persistArtifact: false
        )
        if case .succeeded = state {
            return NaturalStepExecution(step: step, descriptor: descriptor, state: state)
        }

        for fallback in step.fallbackInputs {
            let fallbackState = await ToolExecutionRouter.shared.run(
                descriptor,
                input: fallback,
                bypassApproval: false,
                path: path,
                persistArtifact: false
            )
            state = fallbackState
            if case .succeeded = fallbackState {
                break
            }
        }
        return NaturalStepExecution(step: step, descriptor: descriptor, state: state)
    }
}

enum NaturalResultComposer {
    static func compose(plan: NaturalWorkPlan, executions: [NaturalStepExecution]) -> NaturalWorkResult {
        var sections: [NaturalResultSection] = []
        var missing = plan.preflightMissingSections

        for execution in executions {
            switch execution.state {
            case .succeeded(let result):
                sections.append(NaturalResultSection(
                    title: execution.step.sectionTitle,
                    summary: result.summary,
                    body: result.body,
                    sourceLabel: result.sourceLabel,
                    sourceLinks: result.items.compactMap(\.sourceURL)
                ))
            default:
                missing.append(missingSection(for: execution))
            }
        }

        let notices = notices(for: plan)
        let statusSuffix = missing.isEmpty ? "" : " · 일부 항목 확인 필요"
        let title = "\(plan.title)\(statusSuffix)"
        let markdown = markdown(
            title: title,
            plan: plan,
            sections: sections,
            missing: missing,
            notices: notices
        )
        return NaturalWorkResult(
            planTitle: plan.title,
            sections: sections,
            missingSections: missing,
            notices: notices,
            artifactTitle: title,
            artifactMarkdown: markdown
        )
    }

    private static func markdown(
        title: String,
        plan: NaturalWorkPlan,
        sections: [NaturalResultSection],
        missing: [NaturalMissingSection],
        notices: [String]
    ) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "## 한 줄 요약",
            sections.isEmpty
                ? "요청한 항목을 확인하지 못했습니다. 아래 확인 필요 항목을 먼저 처리하세요."
                : "\(plan.request.originalText)을 \(sections.count)개 항목으로 확인했습니다."
        ]

        for section in sections {
            lines.append("")
            lines.append("## \(section.title)")
            lines.append(section.summary)
            if let source = section.sourceLabel, !source.isEmpty {
                lines.append("")
                lines.append("근거: \(source)")
            }
            if let body = section.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                lines.append("")
                lines.append(body)
            }
            if !section.sourceLinks.isEmpty {
                lines.append("")
                lines.append("원문 링크")
                for url in Array(Set(section.sourceLinks)).prefix(5) {
                    lines.append("- \(url.absoluteString)")
                }
            }
        }

        if !missing.isEmpty {
            lines.append("")
            lines.append("## 확인하지 못한 항목")
            for item in missing {
                lines.append("- \(item.title): \(item.reason)")
                if let next = item.nextAction {
                    lines.append("  - 다음 행동: \(next)")
                }
            }
        }

        if !notices.isEmpty {
            lines.append("")
            lines.append("## 고지")
            for notice in notices {
                lines.append("- \(notice)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func missingSection(for execution: NaturalStepExecution) -> NaturalMissingSection {
        switch execution.state {
        case .needsConnection(let provider):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: "\(provider.displayName) 연결이 필요합니다.",
                nextAction: "설정에서 개인 키를 연결한 뒤 다시 시도하세요."
            )
        case .needsValidation(let provider):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: "\(provider.displayName) 연결 검증이 필요합니다.",
                nextAction: "설정에서 연결 상태를 검증하세요."
            )
        case .needsAssistantConnection(let provider):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: "\(provider.displayName) 연결이 필요합니다.",
                nextAction: "설정에서 연결한 뒤 다시 시도하세요."
            )
        case .failed(let failure):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: failure.message,
                nextAction: failure.recoveryActions.first?.title
            )
        case .unavailable(let reason), .needsApproval(let reason):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: reason,
                nextAction: "다른 입력으로 다시 시도하세요."
            )
        default:
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: "결과를 확인하지 못했습니다.",
                nextAction: "잠시 후 다시 시도하세요."
            )
        }
    }

    private static func notices(for plan: NaturalWorkPlan) -> [String] {
        var notices: [String] = []
        if let notice = plan.userNotice {
            notices.append(notice)
        }
        if plan.request.intents.contains(.stockPrice) || plan.request.intents.contains(.companyOverview) || plan.request.intents.contains(.companyFinance) {
            notices.append("금융위원회 기준일 공공데이터이며 실시간 시세가 아닙니다.")
            notices.append("투자 조언이 아닙니다.")
        }
        if plan.request.intents.contains(.news) || plan.request.intents.contains(.companyOverview) {
            notices.append("뉴스는 검색 결과의 제목과 설명 기준입니다. 기사 전문은 원문 링크에서 확인하세요.")
        }
        if plan.request.intents.contains(.disclosure) || plan.request.intents.contains(.companyOverview) {
            notices.append("공시 원문은 DART 공식 링크에서 확인하세요.")
        }
        if plan.request.intents.contains(.law) {
            notices.append("이 결과는 법령 검색 결과이며 법률 자문이 아닙니다. 최종 판단은 공식 법령 원문과 전문가 검토가 필요합니다.")
        }
        var seen = Set<String>()
        return notices.filter { seen.insert($0).inserted }
    }
}

enum CompositeWorkArtifactWriter {
    static func write(result: NaturalWorkResult, originalText: String) async -> IndexedArtifact? {
        let filename = filename(for: result.artifactTitle)
        let store = ArtifactStore.shared
        let fileURL = store.workspaceURL.appendingPathComponent(filename)
        do {
            try result.artifactMarkdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.warning("[CompositeWorkArtifactWriter] artifact write failed: \(error.localizedDescription)")
            return nil
        }

        let now = Date()
        let roomID = await MainActor.run { AgentWindowManager.shared.currentRoomID }
        let workflowID = await MainActor.run { AgentWindowManager.shared.currentWorkflowID } ?? UUID()
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: result.artifactTitle,
            type: .report,
            filename: filename,
            relativePath: filename,
            preview: String(result.artifactMarkdown.prefix(200)),
            createdAt: ISO8601DateFormatter().string(from: now),
            contentHash: StableContentHash.sha256Hex(result.artifactMarkdown),
            fileSizeBytes: Int64(result.artifactMarkdown.utf8.count),
            roomID: roomID?.uuidString
        )
        await store.registerArtifact(artifact)

        if let roomID {
            await MainActor.run {
                AgentWindowManager.shared.addRecentArtifactIndexEntry(RecentArtifactIndexEntry(
                    artifactID: artifact.id,
                    roomID: roomID,
                    filename: filename,
                    artifactType: artifact.type.rawValue,
                    createdAt: now,
                    contentHash: artifact.contentHash,
                    fileSizeBytes: artifact.fileSizeBytes
                ))
            }
        }
        return artifact
    }

    private static func filename(for title: String) -> String {
        let timestamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let slug = title
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "·", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return "work-artifact-\(String(slug.prefix(48)))-\(timestamp).md"
    }
}
