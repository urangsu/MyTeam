import Foundation
import Combine

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

enum NaturalWorkType: String, Sendable, Equatable, Codable {
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

enum NaturalWorkRouteDecision: Sendable, Equatable {
    case plan(NaturalWorkPlan)
    case clarification(NaturalClarificationRequest)
    case fallback
    case unsupported(String)
}

struct NaturalClarificationRequest: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    let originalText: String
    let workType: NaturalWorkType
    let missingSlots: [NaturalWorkSlot]
    let question: String
    let suggestions: [String]
    let createdAt: Date
    let roomID: UUID?
}

enum NaturalWorkSlot: String, Sendable, Equatable, Codable {
    case targetCompany
    case sourceText
    case sourceFile
    case targetPeriod
    case reportAudience
    case outputFormat
    case region
    case newsTopic
    case lawTopic
    case spreadsheetRange
}

struct NaturalMissingStep: Sendable, Equatable {
    let stepID: String
    let title: String
    let reason: String
    let nextAction: String?
}

struct NaturalBlockedStep: Sendable, Equatable {
    let stepID: String
    let title: String
    let reason: String
}

struct NaturalWorkPlanValidationResult: Sendable, Equatable {
    let executableSteps: [NaturalToolStep]
    let missingSteps: [NaturalMissingStep]
    let blockedSteps: [NaturalBlockedStep]
    let needsClarification: NaturalClarificationRequest?
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

@MainActor
final class PendingNaturalWorkRequestStore: ObservableObject {
    static let shared = PendingNaturalWorkRequestStore()

    @Published private var pendingByRoomKey: [String: NaturalClarificationRequest] = [:]

    private init() {}

    func set(_ request: NaturalClarificationRequest, roomID: UUID?) {
        pendingByRoomKey[key(for: roomID)] = request
    }

    func pending(roomID: UUID?) -> NaturalClarificationRequest? {
        pendingByRoomKey[key(for: roomID)]
    }

    func clear(roomID: UUID?) {
        pendingByRoomKey.removeValue(forKey: key(for: roomID))
    }

    func mergeAnswer(_ answer: String, into request: NaturalClarificationRequest) -> NaturalWorkRequest {
        NaturalWorkRequest(
            originalText: mergedText(answer, into: request),
            entities: [],
            intents: intents(for: request.workType),
            confidence: .medium,
            clarificationQuestion: nil
        )
    }

    func mergedText(_ answer: String, into request: NaturalClarificationRequest) -> String {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAnswer.isEmpty { return request.originalText }
        return "\(request.originalText)\n\n\(trimmedAnswer)"
    }

    nonisolated static func isCancellation(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["취소", "그만", "아니 됐어", "됐어", "취소해줘", "중단"].contains(normalized)
    }

    private func key(for roomID: UUID?) -> String {
        roomID?.uuidString ?? "global"
    }

    private func intents(for workType: NaturalWorkType) -> [NaturalIntent] {
        switch workType {
        case .companyBriefing: return [.companyOverview]
        case .meetingMinutes: return [.meetingMinutes]
        case .reportDraft: return [.documentDraft]
        case .budgetReview: return [.budgetReview]
        case .closingVarianceAnalysis: return [.closingVarianceAnalysis]
        case .tableCleanupPlan: return [.tableCleanupPlan]
        case .lawIssueReview: return [.law]
        case .schedulePreparation: return [.schedulePreparation]
        case .newsBriefing: return [.news]
        case .disclosureReview: return [.disclosure]
        case .evidenceCheck: return [.evidenceCheck]
        case .fileSummary: return [.fileSummary]
        }
    }
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
    static func route(for message: String, context: NaturalWorkContext = .empty) -> NaturalWorkRouteDecision {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .fallback }

        if let clarification = clarificationRequest(for: normalized, context: context) {
            return .clarification(clarification)
        }
        if let plan = plan(for: normalized, context: context) {
            return .plan(plan)
        }
        return .fallback
    }

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
            return weatherPlan(for: normalized, context: context)
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

    private static func clarificationRequest(for text: String, context: NaturalWorkContext) -> NaturalClarificationRequest? {
        let lower = text.lowercased()
        let roomID = context.roomID

        if isAmbiguousCompanyRequest(lower),
           context.lastCompanyIdentity == nil,
           CompanyIdentityResolver.resolve(from: text) == nil {
            return NaturalClarificationRequest(
                id: UUID(),
                originalText: text,
                workType: .companyBriefing,
                missingSlots: [.targetCompany],
                question: "어느 회사를 기준으로 볼까요?\n회사명이나 종목코드를 입력해 주세요. 예: 삼성전자, 005930",
                suggestions: ["삼성전자", "005930", "포스코홀딩스"],
                createdAt: Date(),
                roomID: roomID
            )
        }

        if isWeatherRequest(lower),
           context.userLocation == nil,
           weatherRegionCandidate(from: text).isEmpty {
            return NaturalClarificationRequest(
                id: UUID(),
                originalText: text,
                workType: .schedulePreparation,
                missingSlots: [.region],
                question: "어느 지역의 날씨를 확인할까요?\n예: 광양, 포항, 서울",
                suggestions: ["광양", "포항", "서울"],
                createdAt: Date(),
                roomID: roomID
            )
        }

        if isNewsRequest(lower),
           !hasCompanyCompositeCue(lower),
           cleaned(text, removing: ["뉴스", "검색", "찾아줘", "조회", "브리핑", "최신"], fallback: "").isEmpty {
            return NaturalClarificationRequest(
                id: UUID(),
                originalText: text,
                workType: .newsBriefing,
                missingSlots: [.newsTopic],
                question: "어떤 주제의 뉴스를 확인할까요?\n회사명, 산업, 키워드를 입력해 주세요. 예: 삼성전자, 리튬, 반도체",
                suggestions: ["삼성전자", "리튬", "반도체"],
                createdAt: Date(),
                roomID: roomID
            )
        }

        if isLawRequest(lower),
           cleaned(text, removing: ["법령", "법률", "조문", "검색", "찾아줘", "조회", "관련해서", "뭘", "봐야", "해"], fallback: "").isEmpty {
            return NaturalClarificationRequest(
                id: UUID(),
                originalText: text,
                workType: .lawIssueReview,
                missingSlots: [.lawTopic],
                question: "어떤 법령이나 쟁점을 확인할까요?\n법령명이나 주제를 입력해 주세요. 예: 근로기준법 연차, 주52시간",
                suggestions: ["근로기준법 연차", "주52시간", "산업안전보건법"],
                createdAt: Date(),
                roomID: roomID
            )
        }

        if isMeetingMinutesRequest(lower) && !hasUsableSource(bestSourceText(for: text, context: context), originalText: text) {
            return NaturalClarificationRequest(
                id: UUID(),
                originalText: text,
                workType: .meetingMinutes,
                missingSlots: [.sourceText, .sourceFile],
                question: "회의록으로 정리할 내용이 필요합니다.\n회의 녹취록, 메모, 또는 파일을 붙여넣어 주세요.",
                suggestions: ["회의 메모 붙여넣기", "녹취록 첨부", "파일 첨부"],
                createdAt: Date(),
                roomID: roomID
            )
        }

        if isBudgetReviewRequest(lower) || isClosingVarianceRequest(lower) || isTableCleanupRequest(lower) {
            let source = bestSourceText(for: text, context: context)
            guard hasTabularCue(source) || hasAttachmentOrRecentContext(context) else {
                let workType: NaturalWorkType = isClosingVarianceRequest(lower) ? .closingVarianceAnalysis : (isBudgetReviewRequest(lower) ? .budgetReview : .tableCleanupPlan)
                return NaturalClarificationRequest(
                    id: UUID(),
                    originalText: text,
                    workType: workType,
                    missingSlots: [.sourceFile, .sourceText, .targetPeriod],
                    question: "분석할 표나 파일이 필요합니다.\n예산/실적 표를 붙여넣거나 엑셀 파일을 첨부해 주세요.\n기준은 전년 대비, 계획 대비, 예산 대비 중 무엇인지도 알려주세요.",
                    suggestions: ["표 붙여넣기", "엑셀 파일 첨부", "계획 대비 기준"],
                    createdAt: Date(),
                    roomID: roomID
                )
            }
        }

        if isDocumentDraftRequest(lower) || isFollowUpRewriteRequest(lower) || isFileSummaryRequest(lower) {
            let source = bestSourceText(for: text, context: context)
            if !hasUsableSource(source, originalText: text),
               !hasAttachmentOrRecentContext(context),
               isSourceRequiredDraftRequest(lower) {
                return NaturalClarificationRequest(
                    id: UUID(),
                    originalText: text,
                    workType: .reportDraft,
                    missingSlots: [.sourceText, .sourceFile, .outputFormat],
                    question: "정리할 자료가 필요합니다. 텍스트를 붙여넣거나 파일을 첨부해 주세요.\n원하는 결과 형식이 회의록, 보고문구, 체크리스트 중 무엇인지도 알려주시면 더 정확합니다.",
                    suggestions: ["텍스트 붙여넣기", "파일 첨부", "보고문구", "체크리스트"],
                    createdAt: Date(),
                    roomID: roomID
                )
            }
        }

        return nil
    }

    static func runningMarkdown(for plan: NaturalWorkPlan) -> String {
        """
        ### 요청을 확인하고 있습니다

        \(plan.userFacingSummary)
        """
    }

    static func clarificationMarkdown(for request: NaturalClarificationRequest) -> String {
        var lines = [
            "### 정보가 더 필요합니다",
            "",
            request.question
        ]
        if !request.suggestions.isEmpty {
            lines.append("")
            lines.append("예시")
            for suggestion in request.suggestions.prefix(4) {
                lines.append("- \(suggestion)")
            }
        }
        return lines.joined(separator: "\n")
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
        style: NaturalWorkCompositionStyle,
        additionalMissingSections: [NaturalMissingSection] = []
    ) -> NaturalWorkPlan {
        var steps: [NaturalToolStep] = []
        let preflightMissingSections = additionalMissingSections
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
            steps.append(NaturalToolStep(
                id: "company-finance",
                toolID: "finance.company.statement",
                input: MyTeamToolInput(
                    query: FinancePeriodResolver.query(company: companyQuery, originalText: originalText),
                    displayCount: 10
                ),
                fallbackInputs: [],
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
            preflightMissingSections: preflightMissingSections
        )
    }

    private static func newsPlan(for text: String) -> NaturalWorkPlan {
        let query = cleaned(text, removing: ["뉴스", "검색", "찾아줘", "조회", "브리핑", "최신"], fallback: "")
        guard !query.isEmpty else {
            return missingInputPlan(
                originalText: text,
                workType: .newsBriefing,
                intent: .news,
                title: "뉴스 주제 확인",
                summary: "뉴스 검색 주제가 필요합니다.",
                missingTitle: "뉴스 주제",
                reason: "회사명, 산업, 키워드가 있어야 뉴스 검색 결과를 정확히 가져올 수 있습니다.",
                nextAction: "예: 삼성전자 뉴스, 리튬 관련 뉴스처럼 주제를 입력하세요."
            )
        }
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

    private static func weatherPlan(for text: String, context: NaturalWorkContext) -> NaturalWorkPlan {
        let query = cleaned(
            text,
            removing: ["출장", "외근", "현장작업", "날씨", "오늘", "괜찮아", "알려줘", "봐줘"],
            fallback: context.userLocation ?? ""
        )
        guard !query.isEmpty else {
            return missingInputPlan(
                originalText: text,
                workType: .schedulePreparation,
                intent: .weather,
                title: "날씨 지역 확인",
                summary: "확인할 지역이 필요합니다.",
                missingTitle: "지역",
                reason: "날씨 조회에는 지역명이 필요합니다.",
                nextAction: "예: 광양 날씨, 포항 현장작업 날씨처럼 지역을 입력하세요."
            )
        }
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
        let query = cleaned(text, removing: ["법령", "법률", "조문", "검색", "찾아줘", "조회", "관련해서", "뭘", "봐야", "해"], fallback: "")
        guard !query.isEmpty else {
            return missingInputPlan(
                originalText: text,
                workType: .lawIssueReview,
                intent: .law,
                title: "법령 주제 확인",
                summary: "확인할 법령명이나 쟁점이 필요합니다.",
                missingTitle: "법령 또는 쟁점",
                reason: "법령 검색에는 법령명, 조문, 또는 쟁점 키워드가 필요합니다.",
                nextAction: "예: 근로기준법 연차, 주52시간 관련 조문처럼 입력하세요."
            )
        }
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
            toolID: "document.rewrite",
            query: """
            아래 자료를 실제 Excel 수정 없이 점검 체크리스트와 확인 질문으로 정리하세요.
            숫자 검산을 완료했다고 단정하지 말고, 확인해야 할 항목을 나열하세요.

            \(source)
            """,
            sectionTitle: sectionTitle,
            notice: "표/엑셀 파일을 직접 수정하거나 실제 검산 완료를 보장하지 않습니다. 붙여넣은 텍스트 기준 점검 초안입니다.",
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

    private static func isAmbiguousCompanyRequest(_ lower: String) -> Bool {
        containsAny(lower, ["그 회사", "이 회사", "저 회사"]) &&
        containsAny(lower, ["봐줘", "알려줘", "재무", "공시", "주가", "시세", "뉴스"])
    }

    private static func isSourceRequiredDraftRequest(_ lower: String) -> Bool {
        containsAny(lower, [
            "이거 정리", "요약해줘", "보고자료로", "보고문구", "임원 보고",
            "뉴스 기사처럼", "캘린더 형식", "공시 양식처럼", "짧게 써줘",
            "자료 요약", "첨부파일", "이 파일"
        ])
    }

    private static func weatherRegionCandidate(from text: String) -> String {
        cleaned(
            text,
            removing: ["출장", "외근", "현장작업", "날씨", "오늘", "괜찮아", "알려줘", "봐줘"],
            fallback: ""
        )
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

enum NaturalWorkPlanValidator {
    static func validate(_ plan: NaturalWorkPlan) -> NaturalWorkPlanValidationResult {
        var executableSteps: [NaturalToolStep] = []
        var missingSteps: [NaturalMissingStep] = []
        var blockedSteps: [NaturalBlockedStep] = []

        for step in plan.steps {
            guard let descriptor = MyTeamToolRegistry.descriptor(id: step.toolID) else {
                blockedSteps.append(NaturalBlockedStep(
                    stepID: step.id,
                    title: step.sectionTitle,
                    reason: "현재 앱에서 실행할 수 없는 항목입니다."
                ))
                continue
            }
            guard descriptor.isImplemented, descriptor.isUserFacing else {
                blockedSteps.append(NaturalBlockedStep(
                    stepID: step.id,
                    title: descriptor.displayName,
                    reason: "아직 사용자에게 제공할 수 없는 항목입니다."
                ))
                continue
            }
            guard descriptor.permissionLevel == .readOnly || descriptor.permissionLevel == .draftOnly else {
                blockedSteps.append(NaturalBlockedStep(
                    stepID: step.id,
                    title: descriptor.displayName,
                    reason: "사용자 승인 없이 실행할 수 없는 작업입니다."
                ))
                continue
            }
            let query = step.input.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !query.isEmpty else {
                missingSteps.append(NaturalMissingStep(
                    stepID: step.id,
                    title: descriptor.displayName,
                    reason: "실행에 필요한 입력이 부족합니다.",
                    nextAction: "대상, 파일, 표, 또는 검색어를 추가로 알려주세요."
                ))
                continue
            }
            executableSteps.append(step)
        }

        let clarification: NaturalClarificationRequest?
        if executableSteps.isEmpty, let firstMissing = missingSteps.first {
            clarification = NaturalClarificationRequest(
                id: UUID(),
                originalText: plan.request.originalText,
                workType: plan.workType,
                missingSlots: [.sourceText],
                question: firstMissing.nextAction ?? "실행에 필요한 정보를 추가로 알려주세요.",
                suggestions: [],
                createdAt: Date(),
                roomID: nil
            )
        } else {
            clarification = nil
        }

        return NaturalWorkPlanValidationResult(
            executableSteps: executableSteps,
            missingSteps: missingSteps,
            blockedSteps: blockedSteps,
            needsClarification: clarification
        )
    }

    static func planAfterValidation(_ plan: NaturalWorkPlan) -> NaturalWorkPlan {
        let validation = validate(plan)
        let missingSections = validation.missingSteps.map {
            NaturalMissingSection(title: $0.title, reason: $0.reason, nextAction: $0.nextAction)
        } + validation.blockedSteps.map {
            NaturalMissingSection(title: $0.title, reason: $0.reason, nextAction: "다른 입력으로 다시 시도하세요.")
        }

        return NaturalWorkPlan(
            request: plan.request,
            workType: plan.workType,
            title: plan.title,
            userFacingSummary: plan.userFacingSummary,
            steps: validation.executableSteps,
            compositionStyle: plan.compositionStyle,
            userNotice: plan.userNotice,
            preflightMissingSections: plan.preflightMissingSections + missingSections
        )
    }
}

enum NaturalWorkPlanExecutor {
    static func execute(
        _ plan: NaturalWorkPlan,
        path: ToolExecutionPath,
        options: ToolExecutionOptions = .composite(parentWorkID: nil)
    ) async -> NaturalWorkResult {
        let validatedPlan = NaturalWorkPlanValidator.planAfterValidation(plan)
        var executions: [NaturalStepExecution] = []
        await withTaskGroup(of: (Int, NaturalStepExecution).self) { group in
            for (index, step) in validatedPlan.steps.enumerated() {
                group.addTask(priority: .userInitiated) {
                    (index, await execute(step, path: path, options: options))
                }
            }
            for await pair in group {
                executions.append(pair.1)
            }
        }
        executions.sort { lhs, rhs in
            let left = validatedPlan.steps.firstIndex(where: { $0.id == lhs.step.id }) ?? 0
            let right = validatedPlan.steps.firstIndex(where: { $0.id == rhs.step.id }) ?? 0
            return left < right
        }
        return NaturalResultComposer.compose(plan: validatedPlan, executions: executions)
    }

    private static func execute(
        _ step: NaturalToolStep,
        path: ToolExecutionPath,
        options: ToolExecutionOptions
    ) async -> NaturalStepExecution {
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
            options: options
        )
        if case .succeeded = state {
            return NaturalStepExecution(step: step, descriptor: descriptor, state: state)
        }
        if case .partial = state {
            return NaturalStepExecution(step: step, descriptor: descriptor, state: state)
        }

        for fallback in step.fallbackInputs {
            let fallbackState = await ToolExecutionRouter.shared.run(
                descriptor,
                input: fallback,
                bypassApproval: false,
                path: path,
                options: options
            )
            state = fallbackState
            if case .succeeded = fallbackState {
                break
            }
            if case .partial = fallbackState {
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
            case .succeeded(let result), .partial(let result):
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
        let nextActions = missing.compactMap { item -> String? in
            guard let next = item.nextAction?.trimmingCharacters(in: .whitespacesAndNewlines), !next.isEmpty else {
                return nil
            }
            return "\(item.title): \(next)"
        }

        var lines: [String] = [
            "# \(title)",
            "",
            "## 한 줄 요약",
            sections.isEmpty
                ? "요청한 항목을 확인하지 못했습니다. 아래 확인 필요 항목을 먼저 처리하세요."
                : "\(plan.request.originalText)을 \(sections.count)개 항목으로 확인했습니다.",
            "",
            "## 확인한 내용"
        ]

        if sections.isEmpty {
            lines.append("- 현재 확인된 항목이 없습니다.")
        } else {
            for section in sections {
                lines.append("- \(section.title): \(section.summary)")
            }
        }

        for section in sections where section.body?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            lines.append("")
            lines.append("## \(section.title)")
            if let body = section.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                lines.append(body)
            }
        }

        let sourceLines = sourceSummaryLines(from: sections)
        if !sourceLines.isEmpty {
            lines.append("")
            lines.append("## 근거와 출처")
            lines.append(contentsOf: sourceLines)
        }

        if !missing.isEmpty {
            lines.append("")
            lines.append("## 확인하지 못한 항목")
            for item in missing {
                lines.append("- \(item.title): \(item.reason)")
            }
        }

        if !nextActions.isEmpty {
            lines.append("")
            lines.append("## 다음 행동")
            for action in nextActions {
                lines.append("- \(action)")
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

    private static func sourceSummaryLines(from sections: [NaturalResultSection]) -> [String] {
        var lines: [String] = []
        var seen = Set<String>()

        for section in sections {
            if let source = section.sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
                let line = "\(section.title): \(source)"
                if seen.insert(line).inserted {
                    lines.append("- \(line)")
                }
            }
            if !section.sourceLinks.isEmpty {
                for url in Array(Set(section.sourceLinks)).prefix(5) {
                    let line = "\(section.title) 원문: \(url.absoluteString)"
                    if seen.insert(line).inserted {
                        lines.append("- \(line)")
                    }
                }
            }
        }
        return lines
    }

    private static func missingSection(for execution: NaturalStepExecution) -> NaturalMissingSection {
        switch execution.state {
        case .checkedEmpty(let result):
            return NaturalMissingSection(
                title: execution.step.sectionTitle,
                reason: result.summary,
                nextAction: result.nextActions.first?.title
            )
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
        let roomID = await MainActor.run { AgentWindowManager.shared.currentRoomID }
        let workflowID = await MainActor.run { roomID.flatMap { AgentWindowManager.shared.currentWorkflowID(for: $0) } ?? AgentWindowManager.shared.currentWorkflowID }
        return await write(
            result: result,
            originalText: originalText,
            roomID: roomID,
            workflowID: workflowID
        )
    }

    static func write(
        result: NaturalWorkResult,
        originalText: String,
        roomID: UUID?,
        workflowID: UUID?
    ) async -> IndexedArtifact? {
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
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: (workflowID ?? UUID()).uuidString,
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
