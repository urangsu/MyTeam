import Foundation

enum BrowserEvidenceConnector {
    static func openAndSnapshot(
        url: URL,
        roomID: UUID,
        chainRunID: UUID
    ) async -> BrowserEvidenceResult {
        let health = await MainActor.run { PlaywrightMCPManager.shared.health }
        guard health.isDOMOperational else {
            return .unavailable(
                health.lastError ?? "Playwright MCP DOM snapshot 커넥터가 준비되지 않았습니다.",
                failureCode: "playwright_mcp_unavailable"
            )
        }

        let snapshot = await PlaywrightMCPClient.shared.navigateAndSnapshot(url: url)
        guard snapshot.ok else {
            return .unavailable(
                snapshot.error ?? "Playwright MCP DOM snapshot 실행에 실패했습니다.",
                failureCode: "browser_snapshot_failed"
            )
        }

        let text = snapshot.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .unavailable("DOM snapshot이 비어 있습니다.", failureCode: "browser_dom_empty")
        }
        let title = firstUsefulLine(in: text) ?? url.host ?? url.absoluteString
        let snapshotID = UUID()

        let record = BrowserSnapshotRecord(
            id: snapshotID,
            roomID: roomID,
            chainRunID: chainRunID,
            url: url.absoluteString,
            title: title,
            text: text,
            capturedAt: Date(),
            sourceType: .browserDOM
        )

        await MainActor.run {
            BrowserSnapshotStore.shared.save(record)
        }

        let source = AgentWindowManager.SourceReference(
            title: title,
            url: url.absoluteString,
            provider: "PlaywrightMCP",
            accessedAt: Date(),
            sourceType: .browserDOM,
            snapshotID: snapshotID
        )
        return BrowserEvidenceResult(
            status: .succeeded,
            sourceRefs: [source],
            snapshotID: snapshotID,
            title: title,
            url: url.absoluteString,
            extractedText: String(text.prefix(5_000)),
            failureCode: nil
        )
    }

    static func openAndExtract(
        url: URL,
        provider: BrowserSearchProvider,
        expectedType: AgentWindowManager.SourceType,
        roomID: UUID,
        chainRunID: UUID
    ) async -> BrowserEvidenceResult {
        let health = await MainActor.run { PlaywrightMCPManager.shared.health }
        guard health.isDOMOperational else {
            return .unavailable(
                health.lastError ?? "Playwright MCP DOM snapshot 커넥터가 준비되지 않았습니다.",
                failureCode: "playwright_mcp_unavailable"
            )
        }

        guard BrowserActionPolicy.decision(for: .navigate, label: url.absoluteString) == .allow else {
            return BrowserEvidenceResult(
                status: .denied,
                sourceRefs: [],
                snapshotID: nil,
                title: nil,
                url: nil,
                extractedText: nil,
                failureCode: "browser_action_denied"
            )
        }

        let snapshot = await PlaywrightMCPClient.shared.navigateAndSnapshot(url: url)
        guard snapshot.ok else {
            return .unavailable(
                snapshot.error ?? "Playwright MCP DOM snapshot 실행에 실패했습니다.",
                failureCode: "browser_snapshot_failed"
            )
        }

        let text = snapshot.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .unavailable("DOM snapshot이 비어 있습니다.", failureCode: "browser_dom_empty")
        }

        let inferredType = sourceType(for: provider, extractedText: text)
        guard inferredType == expectedType else {
            return BrowserEvidenceResult(
                status: .unavailable,
                sourceRefs: [],
                snapshotID: nil,
                title: nil,
                url: nil,
                extractedText: nil,
                failureCode: "browser_source_type_unconfirmed: browser source type mismatch: expected \(expectedType.rawValue), got \(inferredType.rawValue)"
            )
        }

        let title = firstUsefulLine(in: text) ?? url.host ?? url.absoluteString
        let snapshotID = UUID()

        let record = BrowserSnapshotRecord(
            id: snapshotID,
            roomID: roomID,
            chainRunID: chainRunID,
            url: url.absoluteString,
            title: title,
            text: text,
            capturedAt: Date(),
            sourceType: inferredType
        )

        await MainActor.run {
            BrowserSnapshotStore.shared.save(record)
        }

        let source = AgentWindowManager.SourceReference(
            title: title,
            url: url.absoluteString,
            provider: "PlaywrightMCP:\(provider.rawValue)",
            accessedAt: Date(),
            sourceType: inferredType,
            snapshotID: snapshotID
        )
        return BrowserEvidenceResult(
            status: .succeeded,
            sourceRefs: [source],
            snapshotID: snapshotID,
            title: title,
            url: url.absoluteString,
            extractedText: String(text.prefix(5_000)),
            failureCode: nil
        )
    }

    static func searchAndExtract(
        query: String,
        provider: BrowserSearchProvider,
        expectedType: AgentWindowManager.SourceType,
        roomID: UUID,
        chainRunID: UUID
    ) async -> BrowserEvidenceResult {
        let health = await MainActor.run { PlaywrightMCPManager.shared.health }
        guard health.isSearchOperational else {
            return .unavailable(
                health.lastError ?? "Playwright MCP 검색 커넥터가 준비되지 않았습니다.",
                failureCode: "playwright_search_unavailable"
            )
        }

        guard BrowserActionPolicy.decision(for: .searchInput, label: query) == .allow else {
            return BrowserEvidenceResult(
                status: .denied,
                sourceRefs: [],
                snapshotID: nil,
                title: nil,
                url: nil,
                extractedText: nil,
                failureCode: "browser_action_denied"
            )
        }

        let url = searchURL(for: query, provider: provider)
        let snapshot = await PlaywrightMCPClient.shared.navigateAndSnapshot(url: url)
        guard snapshot.ok else {
            return .unavailable(
                snapshot.error ?? "Playwright MCP 검색 DOM 실행에 실패했습니다.",
                failureCode: "browser_search_snapshot_failed"
            )
        }

        let text = snapshot.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .unavailable("검색 결과 DOM이 비어 있습니다.", failureCode: "browser_search_dom_empty")
        }

        let inferredType = sourceType(for: provider, extractedText: text)
        guard inferredType == expectedType else {
            return BrowserEvidenceResult(
                status: .unavailable,
                sourceRefs: [],
                snapshotID: nil,
                title: nil,
                url: nil,
                extractedText: nil,
                failureCode: "browser_source_type_unconfirmed: browser source type mismatch: expected \(expectedType.rawValue), got \(inferredType.rawValue)"
            )
        }

        let title = firstUsefulLine(in: text) ?? query
        let snapshotID = UUID()

        let record = BrowserSnapshotRecord(
            id: snapshotID,
            roomID: roomID,
            chainRunID: chainRunID,
            url: url.absoluteString,
            title: title,
            text: text,
            capturedAt: Date(),
            sourceType: inferredType
        )

        await MainActor.run {
            BrowserSnapshotStore.shared.save(record)
        }

        let source = AgentWindowManager.SourceReference(
            title: title,
            url: url.absoluteString,
            provider: "PlaywrightMCP:\(provider.rawValue)",
            accessedAt: Date(),
            sourceType: inferredType,
            snapshotID: snapshotID
        )
        return BrowserEvidenceResult(
            status: .succeeded,
            sourceRefs: [source],
            snapshotID: snapshotID,
            title: title,
            url: url.absoluteString,
            extractedText: String(text.prefix(5_000)),
            failureCode: nil
        )
    }

    static func sourceType(for provider: BrowserSearchProvider, extractedText: String) -> AgentWindowManager.SourceType {
        let lower = extractedText.lowercased()
        switch provider {
        case .naverFinance:
            return containsQuoteSignal(lower) ? .quote : .browserDOM
        case .naverNews:
            return containsNewsSignal(lower) ? .news : .browserDOM
        case .dart, .kind:
            return containsDisclosureSignal(lower) ? .disclosure : .browserDOM
        case .korail:
            return containsTrainScheduleSignal(lower) ? .trainSchedule : .browserDOM
        case .kakaoMap:
            return containsMapRouteSignal(lower) ? .mapRoute : .browserDOM
        case .naverSearch, .google, .general:
            return .browserDOM
        }
    }

    private static func containsQuoteSignal(_ text: String) -> Bool {
        let hasPrice = text.contains("현재가")
        let hasRate = text.contains("등락률") || text.contains("전일대비")
        let hasVol = text.contains("거래량")
        
        if (hasPrice && hasRate) || (hasPrice && hasVol) || (text.contains("전일대비") && text.contains("등락률")) {
            return true
        }
        
        let hasPercentPattern = text.range(of: #"[-+]\d+(?:\.\d+)?%"#, options: .regularExpression) != nil
        let hasWonPattern = text.range(of: #"\d{1,3}(?:,\d{3})*\s*원"#, options: .regularExpression) != nil
        if hasPercentPattern && hasWonPattern {
            return true
        }
        
        return false
    }

    private static func containsNewsSignal(_ text: String) -> Bool {
        let hasNewsKeyword = text.contains("뉴스") || text.contains("기사") || text.contains("보도")
        let hasPressOrReporter = text.contains("언론사") || text.contains("기자") || text.contains("기재") || text.contains("헤드라인") || text.range(of: #"(?:일보|경제|신문|뉴스|미디어)"#, options: .regularExpression) != nil
        let hasLink = text.contains("http") || text.contains("www.") || text.contains(".com") || text.contains(".co.kr") || text.contains(".net")
        return hasNewsKeyword && hasPressOrReporter && hasLink
    }

    private static func containsDisclosureSignal(_ text: String) -> Bool {
        let hasBase = text.contains("dart") || text.contains("kind") || text.contains("공시") || text.contains("보고서")
        let hasDatePattern = text.range(of: #"\d{4}[-./\s]\d{2}[-./\s]\d{2}"#, options: .regularExpression) != nil || text.contains("날짜") || text.contains("접수일") || text.contains("제출일")
        let hasDisclosureType = text.contains("사업보고서") 
            || text.contains("분기보고서") 
            || text.contains("반기보고서") 
            || text.contains("감사보고서") 
            || text.contains("공시") 
            || text.contains("보고서명") 
            || text.contains("제출")
        return hasBase && hasDatePattern && hasDisclosureType
    }

    private static func containsTrainScheduleSignal(_ text: String) -> Bool {
        let hasStations = text.contains("출발역") && text.contains("도착역")
        let hasTrainAndSchedule = (text.contains("열차 번호") || text.contains("열차번호") || text.contains("ktx") || text.contains("srt")) 
            && (text.contains("시간표") || text.contains("출발 시간") || text.contains("도착 시간"))
        return hasStations || hasTrainAndSchedule
    }

    private static func containsMapRouteSignal(_ text: String) -> Bool {
        let hasTimeAndRoute = text.contains("소요시간") && (text.contains("경로") || text.contains("길찾기"))
        let hasMapActions = text.contains("길찾기") && (text.contains("도보") || text.contains("자동차") || text.contains("대중교통"))
        return hasTimeAndRoute || hasMapActions
    }

    private static func searchURL(for query: String, provider: BrowserSearchProvider) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let raw: String
        switch provider {
        case .naverFinance:
            raw = "https://search.naver.com/search.naver?query=\(encoded)"
        case .naverNews:
            raw = "https://search.naver.com/search.naver?where=news&query=\(encoded)"
        case .dart:
            raw = "https://dart.fss.or.kr/dsab001/main.do?textCrpNm=\(encoded)"
        case .kind:
            raw = "https://kind.krx.co.kr/disclosure/details.do?method=searchDetailsMain&searchCorpName=\(encoded)"
        case .naverSearch:
            raw = "https://search.naver.com/search.naver?query=\(encoded)"
        case .google:
            raw = "https://www.google.com/search?q=\(encoded)"
        case .korail:
            raw = "https://www.letskorail.com/"
        case .kakaoMap:
            raw = "https://map.kakao.com/?q=\(encoded)"
        case .general:
            raw = "https://search.naver.com/search.naver?query=\(encoded)"
        }
        return URL(string: raw) ?? URL(string: "https://search.naver.com/search.naver")!
    }

    private static func firstUsefulLine(in text: String) -> String? {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.count >= 3 }
            .map { String($0.prefix(120)) }
    }
}
