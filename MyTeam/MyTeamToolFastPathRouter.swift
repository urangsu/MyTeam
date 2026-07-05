import Foundation

struct MyTeamToolFastPathMatch: Sendable, Equatable {
    let descriptor: MyTeamToolDescriptor
    let input: MyTeamToolInput
}

enum MyTeamToolFastPathRouter {
    static func match(_ message: String) -> MyTeamToolFastPathMatch? {
        matchMany(message).first
    }

    static func matchMany(_ message: String) -> [MyTeamToolFastPathMatch] {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let lower = normalized.lowercased()

        if let marketMatches = marketBriefingMatches(normalized, lower: lower), !marketMatches.isEmpty {
            return marketMatches
        }

        if isGoogleSheetsReadRequest(normalized, lower: lower) {
            return compact([make("spreadsheet.googleSheets.read", query: normalized)])
        }

        if containsAny(lower, ["오늘 일정", "오늘 회의", "일정 확인", "일정 조회", "캘린더 확인", "캘린더 일정", "calendar events"]) {
            return compact([make("calendar.events.today", query: "오늘 일정")])
        }

        if isWeatherReadRequest(normalized, lower: lower) {
            guard let query = query(afterRemoving: ["날씨", "조회", "기상청"], from: normalized) else { return [] }
            return compact([make("weather.current", query: query)])
        }

        if containsAny(lower, ["뉴스 검색", "뉴스 찾아", "뉴스 조회", "최신 뉴스", "news search"]) {
            guard let query = query(afterRemoving: ["뉴스", "검색", "요약", "찾아줘"], from: normalized) else { return [] }
            return compact([make("news.search", query: query)])
        }

        if isDARTReadRequest(normalized, lower: lower) {
            guard let query = query(afterRemoving: ["공시", "조회", "검색", "DART", "다트"], from: normalized) else { return [] }
            return compact([make("dart.disclosures.search", query: query)])
        }

        if isCompanyFinanceRequest(normalized, lower: lower) {
            guard let query = financeQuery(from: normalized) else { return [] }
            return compact([make("finance.company.statement", query: query)])
        }

        if containsAny(lower, ["법령 검색", "법령 찾아", "법률 검색", "조문 조회", "조문 찾아", "law search"]) {
            guard let query = query(afterRemoving: ["법령", "법률", "조문", "검색", "찾아줘"], from: normalized) else { return [] }
            return compact([make("law.search", query: query)])
        }

        if containsAny(lower, ["회의록", "회의 메모"]) {
            return compact([make("document.meetingMinutes", query: normalized)])
        }

        if containsAny(lower, ["문서 다듬", "문장 다듬", "다듬어", "rewrite"]) {
            return compact([make("document.rewrite", query: normalized)])
        }

        if containsAny(lower, ["엑셀 후처리", "표 정리", "스프레드시트 정리"]) {
            return compact([make("spreadsheet.postprocess", query: normalized)])
        }

        return []
    }

    static func markdown(for state: ToolExecutionState, descriptor: MyTeamToolDescriptor) -> String {
        switch state {
        case .succeeded(let result), .partial(let result):
            var lines = [
                "### \(result.title)",
                "",
                result.summary
            ]
            if let source = result.sourceLabel {
                lines.append("")
                lines.append("출처: \(source)")
            }
            if let body = result.body, !body.isEmpty {
                lines.append("")
                lines.append(body)
            }
            if !result.items.isEmpty {
                lines.append("")
                lines.append("#### 결과")
                for item in result.items.prefix(5) {
                    let subtitle = item.subtitle.map { " — \($0)" } ?? ""
                    lines.append("- \(item.title)\(subtitle)")
                }
            }
            return lines.joined(separator: "\n")
        case .checkedEmpty(let result):
            var lines = [
                "### \(result.title)",
                "",
                result.summary
            ]
            if let source = result.sourceLabel {
                lines.append("")
                lines.append("출처: \(source)")
            }
            if let body = result.body, !body.isEmpty {
                lines.append("")
                lines.append(body)
            }
            if !result.nextActions.isEmpty {
                lines.append("")
                lines.append("#### 다음 행동")
                for action in result.nextActions.prefix(3) {
                    lines.append("- \(action.title)")
                }
            }
            return lines.joined(separator: "\n")
        case .failed(let failure):
            return """
            ### \(failure.title)

            \(failure.message)
            """
        case .needsConnection(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 연결이 필요합니다."
        case .needsAssistantConnection(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 비서 연결이 필요합니다."
        case .needsValidation(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 연결 검증이 필요합니다."
        case .needsApproval(let reason), .unavailable(let reason):
            return reason
        case .running, .checkingReadiness, .idle:
            return "\(descriptor.displayName) 실행 상태를 확인 중입니다."
        }
    }

    static func runningMarkdown(for descriptor: MyTeamToolDescriptor) -> String {
        """
        ### 업무 실행 중: \(descriptor.displayName)

        입력값을 확인하고 결과를 가져오는 중입니다.
        """
    }

    static func runningMarkdown(for matches: [MyTeamToolFastPathMatch]) -> String {
        guard matches.count > 1 else {
            return matches.first.map { runningMarkdown(for: $0.descriptor) } ?? "업무 실행 상태를 확인 중입니다."
        }
        let names = matches.map { "- \($0.descriptor.displayName)" }.joined(separator: "\n")
        return """
        ### 업무 실행 중

        요청을 여러 업무로 나누어 확인합니다.

        \(names)
        """
    }

    static func markdown(for results: [(match: MyTeamToolFastPathMatch, state: ToolExecutionState)]) -> String {
        guard results.count > 1 else {
            if let first = results.first {
                return markdown(for: first.state, descriptor: first.match.descriptor)
            }
            return "실행한 업무가 없습니다."
        }

        var lines = [
            "### 요청한 업무를 묶어서 확인했습니다",
            "",
            "아래 결과는 각 공식/공공 데이터 조회를 분리해 가져온 것입니다."
        ]
        for result in results {
            lines.append("")
            lines.append("---")
            lines.append("")
            lines.append(markdown(for: result.state, descriptor: result.match.descriptor))
        }
        return lines.joined(separator: "\n")
    }

    private static func make(_ id: String, query: String) -> MyTeamToolFastPathMatch? {
        guard let descriptor = MyTeamToolRegistry.descriptor(id: id), descriptor.isUserFacing else { return nil }
        return MyTeamToolFastPathMatch(
            descriptor: descriptor,
            input: MyTeamToolInput(
                query: query,
                daysBack: id == "dart.disclosures.search" ? 30 : nil,
                displayCount: id == "news.search" ? 5 : nil,
                providerHint: descriptor.requiredCredential?.provider.externalProvider
            )
        )
    }

    private static func compact(_ matches: [MyTeamToolFastPathMatch?]) -> [MyTeamToolFastPathMatch] {
        matches.compactMap { $0 }
    }

    private static func marketBriefingMatches(_ message: String, lower: String) -> [MyTeamToolFastPathMatch]? {
        let hasMarketIntent = containsAny(lower, [
            "주가", "주식", "시세", "공시", "공시사항", "재무", "재무상황", "재무제표", "실적", "뉴스", "최근 소식"
        ])
        guard hasMarketIntent else { return nil }
        guard let company = companyQuery(from: message), !company.isEmpty else { return nil }

        var matches: [MyTeamToolFastPathMatch?] = []
        if containsAny(lower, ["주가", "주식", "시세"]) {
            matches.append(make("finance.krx.stockPrice", query: company))
        }
        if containsAny(lower, ["공시", "공시사항", "dart", "다트"]) {
            matches.append(make("dart.disclosures.search", query: company))
        }
        if containsAny(lower, ["재무", "재무상황", "재무제표", "실적", "손익계산서", "재무상태표"]) {
            if let query = financeQuery(from: "\(company) \(message)") {
                matches.append(make("finance.company.statement", query: query))
            }
        }
        if containsAny(lower, ["뉴스", "최근 소식", "이슈"]) {
            matches.append(make("news.search", query: company))
        }

        let resolved = deduplicated(compact(matches))
        return resolved.isEmpty ? nil : resolved
    }

    private static func deduplicated(_ matches: [MyTeamToolFastPathMatch]) -> [MyTeamToolFastPathMatch] {
        var seen = Set<String>()
        var output: [MyTeamToolFastPathMatch] = []
        for match in matches where !seen.contains(match.descriptor.id) {
            seen.insert(match.descriptor.id)
            output.append(match)
        }
        return output
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func isGoogleSheetsReadRequest(_ message: String, lower: String) -> Bool {
        if lower.contains("docs.google.com/spreadsheets") { return true }
        if lower.contains("google sheets") && containsAny(lower, ["읽", "조회", "확인", "가져", "read"]) { return true }
        if containsAny(lower, ["구글시트", "구글 시트"]) && containsAny(lower, ["읽", "조회", "확인", "가져"]) { return true }
        if lower.contains("스프레드시트") && containsAny(lower, ["url", "id", "읽", "조회", "확인", "가져"]) {
            return true
        }
        return message.range(
            of: #"[A-Za-z0-9_-]{25,}\s+[A-Za-z0-9가-힣_ !']+![A-Z]+[0-9]+:[A-Z]+[0-9]+"#,
            options: .regularExpression
        ) != nil
    }

    private static func isWeatherReadRequest(_ message: String, lower: String) -> Bool {
        if containsAny(lower, ["날씨 조회", "날씨 알려", "날씨 확인", "현재 날씨", "기상청 조회", "weather"]) {
            return true
        }
        guard lower.contains("날씨") else { return false }
        if containsAny(lower, ["처럼", "문장", "카피", "기사", "형식"]) { return false }
        let compact = message.replacingOccurrences(of: "날씨", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !compact.isEmpty && compact.count <= 12
    }

    private static func isDARTReadRequest(_ message: String, lower: String) -> Bool {
        if containsAny(lower, ["공시 조회", "공시 검색", "최근 공시", "dart", "다트"]) {
            return true
        }
        guard lower.contains("공시") else { return false }
        if containsAny(lower, ["문장", "형식", "예시", "작성"]) { return false }
        let compact = message.replacingOccurrences(of: "공시", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !compact.isEmpty && compact.count <= 16
    }

    private static func isCompanyFinanceRequest(_ message: String, lower: String) -> Bool {
        if containsAny(lower, ["재무 요약", "요약재무", "재무제표", "손익계산서", "재무상태표", "기업 재무"]) {
            return true
        }
        guard lower.contains("재무") else { return false }
        if containsAny(lower, ["문장처럼", "형식", "예시", "표현"]) { return false }
        let compact = message.replacingOccurrences(of: "재무", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !compact.isEmpty && compact.count <= 24
    }

    private static func financeQuery(from message: String) -> String? {
        guard var query = companyQuery(from: message) ?? query(
            afterRemoving: ["재무", "요약", "요약재무", "재무제표", "손익계산서", "재무상태표", "기업", "조회", "확인", "정리"],
            from: message
        ) else { return nil }
        if
            query.range(of: #"(19|20)\d{2}"#, options: .regularExpression) == nil,
            let yearRange = message.range(of: #"(19|20)\d{2}"#, options: .regularExpression)
        {
            query += " \(message[yearRange])"
        }
        let hasYear = query.range(of: #"(19|20)\d{2}"#, options: .regularExpression) != nil
        return hasYear ? query : "\(query) \(FinancePeriodResolver.latestAvailableToken)"
    }

    private static func companyQuery(from message: String) -> String? {
        var normalized = message
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "·", with: " ")

        let stopWords = [
            "주가", "주식", "시세", "기준일", "공시사항", "공시", "DART", "다트",
            "재무상황", "재무", "재무제표", "요약재무", "손익계산서", "재무상태표", "실적",
            "뉴스", "최근", "소식", "이슈", "알려줘", "보여줘", "정리해줘", "조회해줘",
            "알려", "정리", "조회", "확인", "분석", "그리고", "랑", "와", "과", "도", "좀", "해줘"
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
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func query(afterRemoving tokens: [String], from message: String) -> String? {
        var result = message
        for token in tokens {
            result = result.replacingOccurrences(of: token, with: "", options: [.caseInsensitive])
        }
        result = result
            .replacingOccurrences(of: "해줘", with: "")
            .replacingOccurrences(of: "알려줘", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
