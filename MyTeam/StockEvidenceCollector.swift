import Foundation

struct StockEvidenceRequest: Sendable {
    let rawQuery: String
    let companyName: String?
    let ticker: String?
    let dateRange: DateInterval?
    let roomID: UUID
    let chainRunID: UUID?
}

struct StockEvidenceBundle: Sendable {
    let quote: AgentWindowManager.SourceReference?
    let news: [AgentWindowManager.SourceReference]
    let disclosures: [AgentWindowManager.SourceReference]
    let marketContext: [AgentWindowManager.SourceReference]
    let warnings: [String]

    var promptContext: String {
        let sections = [
            quote.map { "[시세 출처]\n- \($0.title)\n  \($0.url)" },
            news.isEmpty ? nil : "[뉴스 출처]\n" + news.map { "- \($0.title)\n  \($0.url)" }.joined(separator: "\n"),
            disclosures.isEmpty ? nil : "[공시 출처]\n" + disclosures.map { "- \($0.title)\n  \($0.url)" }.joined(separator: "\n"),
            marketContext.isEmpty ? nil : "[시장 맥락 출처]\n" + marketContext.map { "- \($0.title)\n  \($0.url)" }.joined(separator: "\n"),
            warnings.isEmpty ? nil : "[주의]\n" + warnings.map { "- \($0)" }.joined(separator: "\n")
        ].compactMap { $0 }
        return sections.joined(separator: "\n\n")
    }

    var sources: [AgentWindowManager.SourceReference] {
        [quote].compactMap { $0 } + news + disclosures + marketContext
    }
}

enum StockEvidenceCollector {
    static func collect(_ request: StockEvidenceRequest, health: ConnectorHealth) async -> ToolEvidenceResult {
        let resolution = resolveRequest(request)
        let company = request.companyName ?? resolution?.companyName ?? request.rawQuery
        let ticker = request.ticker ?? resolution?.ticker
        var warnings: [String] = []
        let canSearchNews = health.newsSearch.isOperational || health.webFetch.isOperational
        let canSearchMarketContext = health.webFetch.isOperational

        async let quoteEvidence = gatherQuote(company: company, ticker: ticker, health: health)
        async let browserQuoteEvidence = gatherBrowser(
            query: "\(company) \(ticker ?? "") 주가 현재가 등락률 거래량",
            provider: .naverFinance,
            sourceType: .quote,
            roomID: request.roomID,
            chainRunID: request.chainRunID,
            enabled: health.browserSearch.isOperational || health.browserDOM.isOperational
        )
        async let newsEvidence = gatherWeb(
            query: "\(company) 하락 상승 이유 뉴스 오늘",
            sourceType: .news,
            enabled: canSearchNews
        )
        async let browserNewsEvidence = gatherBrowser(
            query: "\(company) 하락 상승 이유 뉴스 오늘",
            provider: .naverNews,
            sourceType: .news,
            roomID: request.roomID,
            chainRunID: request.chainRunID,
            enabled: health.browserSearch.isOperational || health.browserDOM.isOperational
        )
        async let disclosureEvidence = gatherDisclosure(company: company, health: health)
        async let browserDisclosureEvidence = gatherBrowser(
            query: "\(company) DART KIND 공시 최근",
            provider: .dart,
            sourceType: .disclosure,
            roomID: request.roomID,
            chainRunID: request.chainRunID,
            enabled: health.browserSearch.isOperational || health.browserDOM.isOperational
        )
        async let marketEvidence = gatherWeb(
            query: "\(company) 업종 지수 환율 코스피 코스닥 영향",
            sourceType: .marketIndex,
            enabled: canSearchMarketContext
        )
        async let browserMarketEvidence = gatherBrowser(
            query: "\(company) 업종 지수 환율 코스피 코스닥 영향",
            provider: .naverSearch,
            sourceType: .marketIndex,
            roomID: request.roomID,
            chainRunID: request.chainRunID,
            enabled: health.browserSearch.isOperational || health.browserDOM.isOperational
        )

        let quoteResult = await quoteEvidence
        let browserQuote = await browserQuoteEvidence
        let newsResult = await newsEvidence
        let browserNews = await browserNewsEvidence
        let browserDisclosure = await browserDisclosureEvidence
        let disclosureResult = await disclosureEvidence
        let marketResult = await marketEvidence
        let browserMarket = await browserMarketEvidence
        let news = newsResult + browserNews.sources
        let disclosures = disclosureResult + browserDisclosure.sources
        let market = marketResult + browserMarket.sources

        if ticker == nil {
            warnings.append("종목 코드를 확정하지 못해 시세 조회 정확도가 낮습니다.")
        }
        let quote = quoteResult.quote ?? browserQuote.sources.first(where: { $0.resolvedSourceType == .quote })
        if quote == nil {
            warnings.append("시세 출처를 확인하지 못했습니다. 오늘 변동은 단정하지 않습니다.")
        }
        if news.isEmpty && disclosures.isEmpty {
            warnings.append("뉴스나 공시 근거가 부족해 원인을 단정하지 않습니다.")
        }

        let bundle = StockEvidenceBundle(
            quote: quote,
            news: news,
            disclosures: disclosures,
            marketContext: market,
            warnings: warnings
                + quoteResult.warnings
                + browserQuote.warnings
                + browserNews.warnings
                + browserDisclosure.warnings
                + browserMarket.warnings
        )

        return ToolEvidenceResult(
            promptContext: bundle.promptContext.isEmpty ? "" : "\n\n[주가 체인 수집 자료]\n" + bundle.promptContext,
            sources: dedupe(bundle.sources)
        )
    }

    private static func resolveRequest(_ request: StockEvidenceRequest) -> KoreanStockSymbolResolver.Resolution? {
        if let company = request.companyName, let ticker = request.ticker {
            return KoreanStockSymbolResolver.Resolution(companyName: company, ticker: ticker)
        }
        return KoreanStockSymbolResolver.resolve(request.rawQuery)
    }

    private static func gatherQuote(company: String, ticker: String?, health: ConnectorHealth) async -> (quote: AgentWindowManager.SourceReference?, warnings: [String]) {
        guard health.stockQuote.isOperational else {
            return (nil, [health.stockQuote.reason ?? "시세 조회 커넥터가 설정되지 않았습니다."])
        }
        guard let ticker, !ticker.isEmpty else {
            return (nil, ["종목 코드가 없어 시세 조회를 건너뛰었습니다."])
        }

        let policy = ToolPolicyDecision(
            needsTool: true,
            needsWeb: false,
            needsFinance: true,
            needsURLFetch: false,
            needsCurrentTime: true,
            recommendedTools: ["finance_quote"],
            reason: "stock quote source"
        )
        let evidence = await ToolEvidenceService.gather(for: "\(company) \(ticker) 주가", policy: policy)
        let quote = evidence.sources.first(where: { $0.resolvedSourceType == .quote })
        return (quote, quote == nil ? ["finance quote source를 확인하지 못했습니다."] : [])
    }

    private static func gatherDisclosure(company: String, health: ConnectorHealth) async -> [AgentWindowManager.SourceReference] {
        guard health.disclosureSearch.isOperational || health.webFetch.isOperational else { return [] }
        let sources = await gatherWeb(query: "\(company) DART KIND 공시 최근", sourceType: .disclosure, enabled: true)
        return sources.filter { source in
            let haystack = "\(source.title) \(source.url) \(source.provider)".lowercased()
            return haystack.contains("dart")
                || haystack.contains("kind")
                || haystack.contains("공시")
                || haystack.contains("사업보고서")
                || haystack.contains("분기보고서")
                || haystack.contains("반기보고서")
        }
    }

    private static func gatherWeb(
        query: String,
        sourceType: AgentWindowManager.SourceType,
        enabled: Bool
    ) async -> [AgentWindowManager.SourceReference] {
        guard enabled else { return [] }
        let policy = ToolPolicyDecision(
            needsTool: true,
            needsWeb: true,
            needsFinance: false,
            needsURLFetch: false,
            needsCurrentTime: true,
            recommendedTools: ["web_search"],
            reason: "stock evidence web source"
        )
        let evidence = await ToolEvidenceService.gather(for: query, policy: policy)
        return evidence.sources.map { source in
            AgentWindowManager.SourceReference(
                id: source.id,
                title: source.title,
                url: source.url,
                provider: source.provider,
                accessedAt: source.accessedAt,
                sourceType: sourceType
            )
        }
    }

    private static func gatherBrowser(
        query: String,
        provider: BrowserSearchProvider,
        sourceType: AgentWindowManager.SourceType,
        roomID: UUID,
        chainRunID: UUID?,
        enabled: Bool
    ) async -> (sources: [AgentWindowManager.SourceReference], warnings: [String]) {
        guard enabled else { return ([], []) }
        let result = await BrowserEvidenceConnector.searchAndExtract(
            query: query,
            provider: provider,
            roomID: roomID,
            chainRunID: chainRunID
        )
        guard result.status == .succeeded || result.status == .partial else {
            return ([], result.failureCode.map { ["브라우저 근거 수집 실패: \($0)"] } ?? [])
        }
        let typed = result.sourceRefs.map { source in
            AgentWindowManager.SourceReference(
                id: source.id,
                title: source.title,
                url: source.url,
                provider: source.provider,
                accessedAt: source.accessedAt,
                sourceType: sourceType
            )
        }
        return (typed, [])
    }

    private static func dedupe(_ sources: [AgentWindowManager.SourceReference]) -> [AgentWindowManager.SourceReference] {
        var seen = Set<String>()
        return sources.filter { source in
            let key = "\(source.resolvedSourceType.rawValue)|\(source.url)|\(source.title)"
            return seen.insert(key).inserted
        }
    }
}
