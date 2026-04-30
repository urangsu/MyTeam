import Foundation

// MARK: - Tool Policy
struct ToolPolicyDecision {
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

struct ToolEvidenceResult {
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
            guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1m") else {
                continue
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let chart = json["chart"] as? [String: Any],
                      let result = (chart["result"] as? [[String: Any]])?.first,
                      let meta = result["meta"] as? [String: Any] else {
                    continue
                }

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
                lines.append(line)

                sources.append(AgentWindowManager.SourceReference(
                    title: "Yahoo Finance \(symbol)",
                    url: "https://finance.yahoo.com/quote/\(symbol)",
                    provider: "Yahoo Finance",
                    accessedAt: Date()
                ))
            } catch {
                lines.append("- \(symbol): 금융 데이터 조회 실패 (\(error.localizedDescription))")
            }
        }

        return (lines.isEmpty ? "" : "[금융 데이터]\n" + lines.joined(separator: "\n"), sources)
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
                let text = cleanHTML(raw)
                lines.append("- \(title)\n\(String(text.prefix(2200)))")
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
                    if let text = topic["Text"] as? String, !text.isEmpty {
                        snippets.append(text)
                    }
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
            "삼성전자": "005930.KS", "삼성": "005930.KS",
            "테슬라": "TSLA", "엔비디아": "NVDA", "애플": "AAPL",
            "마이크로소프트": "MSFT", "구글": "GOOGL", "알파벳": "GOOGL",
            "아마존": "AMZN", "메타": "META",
            "비트코인": "BTC-USD", "이더리움": "ETH-USD",
            "bitcoin": "BTC-USD", "ethereum": "ETH-USD"
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

    private static func cleanHTML(_ html: String) -> String {
        var text = html
        for pattern in [#"<script[\s\S]*?</script>"#, #"<style[\s\S]*?</style>"#, #"<[^>]+>"#] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"].forEach {
            text = text.replacingOccurrences(of: $0.key, with: $0.value)
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

extension AgentTool {
    nonisolated var schemaForCopy: [String: Any] { inputSchema }
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
@MainActor
final class AgentToolRegistry {
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
