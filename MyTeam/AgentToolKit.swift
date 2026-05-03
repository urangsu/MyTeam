import Foundation

// MARK: - Tool Policy
struct ToolPolicyDecision: Sendable {
    let needsTool: Bool
    let needsWeb: Bool
    let needsFinance: Bool
    let needsURLFetch: Bool
    let needsCurrentTime: Bool
    let recommendedTools: [String]
    let reason: String

    var promptSummary: String {
        """
        needsTool=\(needsTool)
        needsWeb=\(needsWeb)
        needsFinance=\(needsFinance)
        needsURLFetch=\(needsURLFetch)
        needsCurrentTime=\(needsCurrentTime)
        recommendedTools=\(recommendedTools.joined(separator: ", "))
        reason=\(reason)
        """
    }
}

struct ToolEvidenceResult: Sendable {
    let promptContext: String
    let sources: [AgentWindowManager.SourceReference]

    static let empty = ToolEvidenceResult(promptContext: "", sources: [])
}

enum ToolPolicy {
    static func evaluate(_ message: String) -> ToolPolicyDecision {
        let lowered = message.lowercased()
        let compact = lowered.replacingOccurrences(of: " ", with: "")

        let needsURLFetch = containsURL(in: message)
        let needsCurrentTime = containsAny(compact, [
            "오늘", "현재", "지금", "요즘", "최근", "이번주", "이번달", "올해",
            "today", "current", "now", "recent", "latest"
        ])
        let needsNews = containsAny(compact, [
            "뉴스", "속보", "기사", "주요뉴스", "헤드라인", "이슈",
            "news", "headline"
        ])
        let needsSearch = containsAny(compact, [
            "검색", "찾아", "알아봐", "조사", "출처", "근거", "자료", "웹",
            "search", "web", "source", "citation", "reference"
        ])
        let needsFinance = containsAny(compact, [
            "주식", "주가", "증시", "나스닥", "코스피", "코스닥", "환율", "시세",
            "티커", "종목", "실적", "배당", "비트코인", "코인",
            "stock", "ticker", "nasdaq", "nyse", "price", "earnings", "crypto", "bitcoin"
        ]) || containsStockTicker(in: message)

        let needsWeb = needsURLFetch || needsNews || needsSearch || needsFinance || needsCurrentTime
        var tools: [String] = []
        if needsCurrentTime { tools.append("get_current_time") }
        if needsURLFetch { tools.append("fetch_url") }
        if needsNews || needsSearch || needsFinance { tools.append("web_search") }
        if needsFinance { tools.append("finance_quote") }

        var reasons: [String] = []
        if needsNews { reasons.append("최신 뉴스/이슈 질문") }
        if needsFinance { reasons.append("주식/시세/금융 데이터 질문") }
        if needsURLFetch { reasons.append("URL 내용 확인 필요") }
        if needsSearch { reasons.append("외부 검색/출처 요구") }
        if needsCurrentTime { reasons.append("현재 시점 의존 질문") }

        return ToolPolicyDecision(
            needsTool: !tools.isEmpty,
            needsWeb: needsWeb,
            needsFinance: needsFinance,
            needsURLFetch: needsURLFetch,
            needsCurrentTime: needsCurrentTime,
            recommendedTools: Array(Set(tools)).sorted(),
            reason: reasons.isEmpty ? "도구 필요 신호 없음" : reasons.joined(separator: ", ")
        )
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func containsURL(in text: String) -> Bool {
        text.range(of: #"https?://[^\s]+"#, options: .regularExpression) != nil
    }

    private static func containsStockTicker(in text: String) -> Bool {
        text.range(of: #"\$[A-Z]{1,5}\b|[A-Z]{1,5}\.(KS|KQ)|\b(AAPL|TSLA|NVDA|MSFT|GOOGL|GOOG|AMZN|META|AMD|NFLX|BTC|ETH)\b"#, options: .regularExpression) != nil
    }
}

enum ToolEvidenceService {
    static func gather(for message: String, policy: ToolPolicyDecision) async -> ToolEvidenceResult {
        guard policy.needsTool else { return .empty }

        var sections: [String] = []
        var sources: [AgentWindowManager.SourceReference] = []

        if policy.needsCurrentTime {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            sections.append("[현재 시간]\n\(formatter.string(from: Date()))")
        }

        if policy.needsFinance {
            let quotes = await fetchFinanceQuotes(from: message)
            if !quotes.context.isEmpty { sections.append(quotes.context) }
            sources.append(contentsOf: quotes.sources)
            sections.append("""
            [금융 답변 안전 규칙]
            금융/투자 관련 답변은 참고 정보일 뿐입니다. 최종 선택과 책임은 사용자 본인에게 있으며, AI와 외부 데이터는 틀리거나 지연될 수 있습니다. 매수/매도 지시처럼 단정하지 말고, 출처와 조회 시각을 확인하도록 안내하세요.
            """)
        }

        if policy.needsURLFetch {
            let fetched = await fetchURLContents(from: message)
            if !fetched.context.isEmpty { sections.append(fetched.context) }
            sources.append(contentsOf: fetched.sources)
        }

        if policy.needsWeb {
            let search = await fetchWebEvidence(query: message)
            if !search.context.isEmpty { sections.append(search.context) }
            sources.append(contentsOf: search.sources)
        }

        guard !sections.isEmpty else { return .empty }
        return ToolEvidenceResult(
            promptContext: "\n\n[도구로 확인한 자료]\n" + sections.joined(separator: "\n\n"),
            sources: dedupeSources(sources)
        )
    }

    private static func fetchFinanceQuotes(from message: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        let symbols = extractFinanceSymbols(from: message)
        guard !symbols.isEmpty else {
            return ("[금융 데이터]\n질문에서 명확한 티커를 찾지 못했습니다. 사용자에게 종목명/티커를 확인해야 합니다.", [])
        }

        var lines: [String] = []
        var sources: [AgentWindowManager.SourceReference] = []

        for symbol in symbols.prefix(4) {
            // 한국 종목 코드 감지 (6자리 숫자 또는 .KS/.KQ suffix)
            let isKorean = symbol.range(of: #"^\d{6}$"#, options: .regularExpression) != nil
                || symbol.hasSuffix(".KS") || symbol.hasSuffix(".KQ")

            if isKorean {
                // NAVER 금융 공개 API 사용 (한국 주식)
                if let result = await fetchNaverFinanceQuote(symbol: symbol) {
                    lines.append(result.line)
                    sources.append(result.source)
                    continue
                }
            }

            // Yahoo Finance v8 API (미국/글로벌 주식 및 NAVER 실패 시 fallback)
            if let result = await fetchYahooFinanceQuote(symbol: symbol) {
                lines.append(result.line)
                sources.append(result.source)
            } else {
                lines.append("- \(symbol): 금융 데이터 조회 실패")
            }
        }

        return (lines.isEmpty ? "" : "[금융 데이터]\n" + lines.joined(separator: "\n"), sources)
    }

    private struct QuoteResult {
        let line: String
        let source: AgentWindowManager.SourceReference
    }

    /// NAVER 금융 공개 API (한국 주식)
    private static func fetchNaverFinanceQuote(symbol: String) async -> QuoteResult? {
        // 종목 코드 정규화 (6자리 숫자만 추출)
        let code: String
        if symbol.range(of: #"^\d{6}$"#, options: .regularExpression) != nil {
            code = symbol
        } else {
            code = String(symbol.prefix(6))
        }
        guard let url = URL(string: "https://m.stock.naver.com/api/stock/\(code)/basic") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let name = json["stockName"] as? String ?? code
            let priceStr = json["closePrice"] as? String ?? json["nowVal"] as? String ?? ""
            let changeRate = json["compareToPreviousClosePrice"] as? String ?? ""
            let changeSign = json["fluctuationsRatio"] as? String ?? ""
            var line = "- \(name) (\(code)): \(priceStr) KRW"
            if !changeRate.isEmpty { line += " / 전일 대비 \(changeRate) (\(changeSign)%)" }
            let source = AgentWindowManager.SourceReference(
                title: "NAVER 금융 \(name)",
                url: "https://finance.naver.com/item/main.nhn?code=\(code)",
                provider: "NAVER 금융",
                accessedAt: Date()
            )
            return QuoteResult(line: line, source: source)
        } catch { return nil }
    }

    /// Yahoo Finance v8 chart API (글로벌 주식)
    private static func fetchYahooFinanceQuote(symbol: String) async -> QuoteResult? {
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1m") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (compatible)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let result = (chart["result"] as? [[String: Any]])?.first,
                  let meta = result["meta"] as? [String: Any] else { return nil }
            let name = meta["shortName"] as? String ?? meta["symbol"] as? String ?? symbol
            let currency = meta["currency"] as? String ?? ""
            let price = meta["regularMarketPrice"] as? Double
            let previousClose = meta["previousClose"] as? Double
            let exchange = meta["exchangeName"] as? String ?? meta["fullExchangeName"] as? String ?? ""
            let marketTime = (meta["regularMarketTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            var line = "- \(name) (\(symbol))"
            if let price { line += ": \(formatNumber(price)) \(currency)" }
            if let price, let previousClose, previousClose != 0 {
                let change = price - previousClose
                let percent = change / previousClose * 100
                line += " / 전일 대비 \(formatSigned(change)) (\(formatSigned(percent))%)"
            }
            if !exchange.isEmpty { line += " / 거래소: \(exchange)" }
            if let marketTime { line += " / 기준: \(marketTime.formatted(date: .abbreviated, time: .shortened))" }
            let source = AgentWindowManager.SourceReference(
                title: "Yahoo Finance \(symbol)",
                url: "https://finance.yahoo.com/quote/\(symbol)",
                provider: "Yahoo Finance",
                accessedAt: Date()
            )
            return QuoteResult(line: line, source: source)
        } catch { return nil }
    }

    private static func fetchURLContents(from message: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        let urls = extractURLs(from: message)
        guard !urls.isEmpty else { return ("", []) }

        var lines: [String] = []
        var sources: [AgentWindowManager.SourceReference] = []

        for url in urls.prefix(2) {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 12
                request.setValue("Mozilla/5.0 MyTeam/1.0", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    lines.append("- \(url.absoluteString): 페이지를 가져오지 못했습니다.")
                    continue
                }
                let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                let title = extractHTMLTitle(from: raw) ?? url.host() ?? "웹페이지"
                let description = extractMetaDescription(from: raw)
                let body = extractMainContent(from: raw)
                var entry = "- \(title)"
                if let desc = description, !desc.isEmpty { entry += "\n요약: \(desc)" }
                entry += "\n\(String(body.prefix(2000)))"
                lines.append(entry)
                sources.append(AgentWindowManager.SourceReference(
                    title: title,
                    url: url.absoluteString,
                    provider: url.host() ?? "URL",
                    accessedAt: Date()
                ))
            } catch {
                lines.append("- \(url.absoluteString): URL 읽기 실패 (\(error.localizedDescription))")
            }
        }

        return (lines.isEmpty ? "" : "[URL 직접 읽기]\n" + lines.joined(separator: "\n\n"), sources)
    }

    private static func fetchWebEvidence(query: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        // 1순위: Gemini Google 검색 그라운딩 (API 키 있을 때)
        let geminiResult = await fetchGeminiGrounding(query: query)
        if !geminiResult.context.isEmpty { return geminiResult }

        // 2순위: OpenAI web_search (API 키 있을 때)
        let openAIResult = await fetchOpenAIWebSearch(query: query)
        if !openAIResult.context.isEmpty { return openAIResult }

        // 3순위: DuckDuckGo Instant Answer (키 불필요 폴백)
        return await fetchDuckDuckGo(query: query)
    }

    // MARK: - Gemini Google 검색 그라운딩 (Google 공식 실시간 검색)

    private static func fetchGeminiGrounding(query: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        let apiKey = KeychainManager.load(key: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else { return ("", []) }

        let modelId = LLMConfigCatalog.shared.configs[.gemini]?.selectedModelId ?? "gemini-2.0-flash"
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)") else {
            return ("", [])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 18

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": query]]]],
            "tools": [["google_search": [String: Any]()]],
            "generationConfig": ["maxOutputTokens": 768, "temperature": 0.1]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first else { return ("", []) }

            var text = ""
            if let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                text = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
            }

            var sources: [AgentWindowManager.SourceReference] = []
            if let meta = first["groundingMetadata"] as? [String: Any],
               let chunks = meta["groundingChunks"] as? [[String: Any]] {
                for chunk in chunks.prefix(6) {
                    if let web = chunk["web"] as? [String: Any],
                       let uri = web["uri"] as? String,
                       let title = web["title"] as? String, !uri.isEmpty {
                        sources.append(AgentWindowManager.SourceReference(
                            title: title, url: uri, provider: "Google 검색", accessedAt: Date()
                        ))
                    }
                }
            }

            guard !text.isEmpty else { return ("", sources) }
            AppLog.debug("[ToolEvidence] Gemini 그라운딩 성공 — 출처 \(sources.count)개")
            return ("[웹 검색 자료 (Google)]\n\(String(text.prefix(1600)))", sources)
        } catch {
            AppLog.debug("[ToolEvidence] Gemini 그라운딩 실패: \(error.localizedDescription)")
            return ("", [])
        }
    }

    // MARK: - OpenAI web_search (Responses API)

    private static func fetchOpenAIWebSearch(query: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        let apiKey = KeychainManager.load(key: "openAIAPIKey") ?? ""
        guard !apiKey.isEmpty else { return ("", []) }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else { return ("", []) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "tools": [["type": "web_search_preview"]],
            "input": query
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let output = json["output"] as? [[String: Any]] else { return ("", []) }

            var text = ""
            for item in output where item["type"] as? String == "message" {
                if let content = item["content"] as? [[String: Any]] {
                    for c in content where c["type"] as? String == "output_text" {
                        text += (c["text"] as? String) ?? ""
                    }
                }
            }

            guard !text.isEmpty else { return ("", []) }
            AppLog.debug("[ToolEvidence] OpenAI web_search 성공")
            return ("[웹 검색 자료 (OpenAI)]\n\(String(text.prefix(1600)))", [])
        } catch {
            AppLog.debug("[ToolEvidence] OpenAI web_search 실패: \(error.localizedDescription)")
            return ("", [])
        }
    }

    // MARK: - DuckDuckGo Instant Answer (폴백)

    private static func fetchDuckDuckGo(query: String) async -> (context: String, sources: [AgentWindowManager.SourceReference]) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            return ("", [])
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ("", []) }

            var snippets: [String] = []
            var sources: [AgentWindowManager.SourceReference] = []

            if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
                snippets.append(abstract)
                let title = (json["Heading"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "DuckDuckGo"
                if let sourceURL = json["AbstractURL"] as? String, !sourceURL.isEmpty {
                    sources.append(AgentWindowManager.SourceReference(title: title, url: sourceURL, provider: "DuckDuckGo", accessedAt: Date()))
                }
            }

            if let answer = json["Answer"] as? String, !answer.isEmpty {
                snippets.append(answer)
            }

            if let topics = json["RelatedTopics"] as? [[String: Any]] {
                for topic in topics.prefix(3) {
                    if let text = topic["Text"] as? String, !text.isEmpty { snippets.append(text) }
                    if let firstURL = topic["FirstURL"] as? String, !firstURL.isEmpty {
                        let title = (topic["Text"] as? String).map { String($0.prefix(48)) } ?? "Related"
                        sources.append(AgentWindowManager.SourceReference(title: title, url: firstURL, provider: "DuckDuckGo", accessedAt: Date()))
                    }
                }
            }

            guard !snippets.isEmpty else { return ("", sources) }
            return ("[웹 검색 자료]\n" + snippets.prefix(4).joined(separator: "\n"), sources)
        } catch {
            return ("[웹 검색 자료]\n검색 실패: \(error.localizedDescription)", [])
        }
    }

    static func extractFinanceSymbols(from message: String) -> [String] {
        var symbols: [String] = []
        let aliases: [String: String] = [
            // 한국 대형주
            "삼성전자": "005930.KS", "삼성": "005930.KS",
            "sk하이닉스": "000660.KS", "하이닉스": "000660.KS",
            "lg에너지솔루션": "373220.KS",
            "현대차": "005380.KS", "현대자동차": "005380.KS",
            "기아": "000270.KS", "기아차": "000270.KS",
            "카카오": "035720.KS",
            "네이버": "035420.KS", "naver": "035420.KS",
            "셀트리온": "068270.KS",
            "삼성바이오로직스": "207940.KS",
            "포스코": "005490.KS", "포스코홀딩스": "005490.KS",
            "lg화학": "051910.KS",
            "삼성sdi": "006400.KS",
            "현대모비스": "012330.KS",
            "sk이노베이션": "096770.KS",
            "카카오뱅크": "323410.KS",
            "크래프톤": "259960.KS",
            "krafton": "259960.KS",
            // 미국 주요주
            "테슬라": "TSLA", "엔비디아": "NVDA", "애플": "AAPL",
            "마이크로소프트": "MSFT", "구글": "GOOGL", "알파벳": "GOOGL",
            "아마존": "AMZN", "메타": "META",
            "오픈ai": "MSFT",  // OpenAI는 비상장 → MS로 근사
            "팔란티어": "PLTR",
            "암": "ARM",
            "브로드컴": "AVGO",
            "인텔": "INTC",
            "amd": "AMD",
            "퀄컴": "QCOM",
            // 가상자산
            "비트코인": "BTC-USD", "이더리움": "ETH-USD",
            "솔라나": "SOL-USD", "리플": "XRP-USD",
            "bitcoin": "BTC-USD", "ethereum": "ETH-USD",
            "solana": "SOL-USD",
            // 환율/지수 키워드는 심볼이 아니라 프롬프트에서 처리 (별도 로직)
        ]
        let lowered = message.lowercased()
        for (keyword, symbol) in aliases where lowered.contains(keyword.lowercased()) {
            symbols.append(symbol)
        }

        let pattern = #"\$([A-Z]{1,5})\b|([0-9]{6}\.(?:KS|KQ))\b|\b(AAPL|TSLA|NVDA|MSFT|GOOGL|GOOG|AMZN|META|AMD|NFLX|BTC|ETH)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
            for match in regex.matches(in: message, range: nsRange) {
                for idx in 1..<match.numberOfRanges where match.range(at: idx).location != NSNotFound {
                    guard let range = Range(match.range(at: idx), in: message) else { continue }
                    var symbol = String(message[range]).uppercased()
                    if symbol == "BTC" { symbol = "BTC-USD" }
                    if symbol == "ETH" { symbol = "ETH-USD" }
                    symbols.append(symbol)
                }
            }
        }

        var seen = Set<String>()
        return symbols.filter { seen.insert($0).inserted }
    }

    static func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, range: nsRange).compactMap { $0.url }
    }

    private static func extractHTMLTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<title[^>]*>(.*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return cleanHTML(String(html[range]))
    }

    /// meta description 추출
    private static func extractMetaDescription(from html: String) -> String? {
        let patterns = [
            #"<meta[^>]+name=["']description["'][^>]+content=["']([^"']{20,}?)["']"#,
            #"<meta[^>]+content=["']([^"']{20,}?)["'][^>]+name=["']description["']"#,
            #"<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']{20,}?)["']"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let desc = cleanHTML(String(html[range]))
                if !desc.isEmpty { return desc }
            }
        }
        return nil
    }

    /// <article>, <main>, 본문 class/id 우선 추출 → 없으면 전체 HTML 사용
    private static func extractMainContent(from html: String) -> String {
        // 1. 시맨틱 태그 순서 시도
        let semanticPatterns: [(String, NSRegularExpression.Options)] = [
            (#"<article[^>]*>([\s\S]*?)</article>"#, [.caseInsensitive]),
            (#"<main[^>]*>([\s\S]*?)</main>"#, [.caseInsensitive]),
            // 일반 div id/class에서 content 키워드
            (#"<div[^>]+(?:id|class)=["'][^"']*(?:article|content|post|entry|story|body|text)[^"']*["'][^>]*>([\s\S]{300,}?)</div>"#, [.caseInsensitive]),
        ]
        for (pattern, opts) in semanticPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: opts),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let content = cleanHTML(String(html[range]))
                if content.count >= 200 { return content }
            }
        }
        // 2. <p> 태그들을 모아 본문 구성 (200자 이상인 단락 우선)
        var paragraphs: [String] = []
        if let pRegex = try? NSRegularExpression(pattern: #"<p[^>]*>([\s\S]*?)</p>"#, options: [.caseInsensitive]) {
            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in pRegex.matches(in: html, range: nsRange) {
                if let range = Range(match.range(at: 1), in: html) {
                    let p = cleanHTML(String(html[range]))
                    if p.count >= 40 { paragraphs.append(p) }
                }
            }
        }
        if paragraphs.count >= 2 {
            return paragraphs.prefix(12).joined(separator: "\n")
        }
        // 3. 전체 HTML 스트립 (폴백)
        return cleanHTML(html)
    }

    private static func cleanHTML(_ html: String) -> String {
        var text = html
        // script / style / 주석 제거
        for pattern in [
            #"<script[\s\S]*?</script>"#,
            #"<style[\s\S]*?</style>"#,
            #"<!--[\s\S]*?-->"#,
            #"<nav[^>]*>[\s\S]*?</nav>"#,
            #"<header[^>]*>[\s\S]*?</header>"#,
            #"<footer[^>]*>[\s\S]*?</footer>"#,
            #"<aside[^>]*>[\s\S]*?</aside>"#,
            #"<[^>]+>"#  // 나머지 태그 일괄 제거
        ] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        // HTML 엔티티
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
            "&laquo;": "«", "&raquo;": "»",
        ]
        entities.forEach { text = text.replacingOccurrences(of: $0.key, with: $0.value) }
        // &#NNNN; 숫자 엔티티
        if let numRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let matches = numRegex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)).reversed()
            for match in matches {
                if let numRange = Range(match.range(at: 1), in: text),
                   let code = Int(text[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: text)!
                    text.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dedupeSources(_ sources: [AgentWindowManager.SourceReference]) -> [AgentWindowManager.SourceReference] {
        var seen = Set<String>()
        return sources.filter { seen.insert($0.url).inserted }
    }

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = abs(value) >= 100 ? 2 : 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatSigned(_ value: Double) -> String {
        let formatted = formatNumber(abs(value))
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
}

// MARK: - Tool 정의
struct AgentTool: Sendable {
    let name: String
    let description: String
    let inputSchema: [String: Any]
    let handler: @Sendable (_ input: [String: Any]) async throws -> String

    func toAnthropicJSON() -> [String: Any] {
        ["name": name, "description": description, "input_schema": inputSchema]
    }
}

// MARK: - Tool 호출/결과
struct AgentToolCall {
    let id: String
    let name: String
    let input: [String: Any]
}

struct AgentToolResult {
    let toolUseId: String
    let content: String
    let isError: Bool
}

// MARK: - Tool Registry
final class AgentToolRegistry: @unchecked Sendable {
    static let shared = AgentToolRegistry()
    private(set) var tools: [String: AgentTool] = [:]

    private init() {
        register(Self.makeCurrentTimeTool())
        register(Self.makeWebSearchTool())
        register(Self.makeFinanceQuoteTool())
    }

    func register(_ tool: AgentTool) { tools[tool.name] = tool }

    func anthropicToolsArray() -> [[String: Any]] {
        tools.values.map { $0.toAnthropicJSON() }
    }

    func execute(_ call: AgentToolCall) async -> AgentToolResult {
        guard let tool = tools[call.name] else {
            return AgentToolResult(toolUseId: call.id, content: "Unknown tool: \(call.name)", isError: true)
        }
        do {
            let output = try await tool.handler(call.input)
            return AgentToolResult(toolUseId: call.id, content: output, isError: false)
        } catch {
            return AgentToolResult(toolUseId: call.id, content: "Tool error: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - 기본 도구 구현
private extension AgentToolRegistry {
    static func makeCurrentTimeTool() -> AgentTool {
        AgentTool(
            name: "get_current_time",
            description: "현재 한국 시간을 ISO8601 형식으로 반환합니다. 약속/일정/날짜 질문에 사용.",
            inputSchema: ["type": "object", "properties": [:], "required": []],
            handler: { _ in
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
                return formatter.string(from: Date())
            }
        )
    }

    static func makeWebSearchTool() -> AgentTool {
        AgentTool(
            name: "web_search",
            description: "DuckDuckGo Instant Answer API로 사실 정보를 검색합니다. 일반 지식/정의/계산 질문에 사용. 최신 뉴스에는 부적합.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "검색어"]
                ],
                "required": ["query"]
            ],
            handler: { input in
                guard let query = input["query"] as? String,
                      let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1")
                else {
                    return "Invalid search query"
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return "Search failed"
                }
                let abstract = (json["AbstractText"] as? String) ?? ""
                let definition = (json["Definition"] as? String) ?? ""
                let answer = (json["Answer"] as? String) ?? ""
                let result = [abstract, definition, answer]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")
                return result.isEmpty ? "No results found for: \(query)" : result
            }
        )
    }

    static func makeFinanceQuoteTool() -> AgentTool {
        AgentTool(
            name: "finance_quote",
            description: "주식/코인 티커의 현재 또는 지연 시세를 조회합니다. 금융 답변은 투자 조언이 아니며 사용자의 선택과 책임이 따릅니다.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "symbol": ["type": "string", "description": "예: AAPL, NVDA, 005930.KS, BTC-USD"]
                ],
                "required": ["symbol"]
            ],
            handler: { input in
                guard let symbol = input["symbol"] as? String else { return "Invalid finance symbol" }
                let policy = ToolPolicyDecision(
                    needsTool: true,
                    needsWeb: true,
                    needsFinance: true,
                    needsURLFetch: false,
                    needsCurrentTime: true,
                    recommendedTools: ["finance_quote"],
                    reason: "금융 시세 조회"
                )
                let evidence = await ToolEvidenceService.gather(for: "$\(symbol) 주가", policy: policy)
                return evidence.promptContext.isEmpty ? "No finance quote found for \(symbol)" : evidence.promptContext
            }
        )
    }
}
