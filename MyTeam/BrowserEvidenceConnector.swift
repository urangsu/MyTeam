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
            return lower.contains("뉴스") || lower.contains("기사") ? .news : .browserDOM
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
        text.contains("현재가")
            || text.contains("전일대비")
            || text.contains("등락률")
            || text.contains("거래량")
            || text.contains("시세")
    }

    private static func containsDisclosureSignal(_ text: String) -> Bool {
        text.contains("dart")
            || text.contains("kind")
            || text.contains("공시")
            || text.contains("사업보고서")
            || text.contains("분기보고서")
            || text.contains("반기보고서")
    }

    private static func containsTrainScheduleSignal(_ text: String) -> Bool {
        text.contains("출발역")
            || text.contains("도착역")
            || text.contains("출발 시간")
            || text.contains("열차 번호")
            || text.contains("열차번호")
            || text.contains("ktx")
            || text.contains("srt")
            || text.contains("시간표")
    }

    private static func containsMapRouteSignal(_ text: String) -> Bool {
        text.contains("소요시간")
            || text.contains("길찾기")
            || text.contains("추천 경로")
            || text.contains("도보")
            || text.contains("자동차 경로")
            || text.contains("대중교통 경로")
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
            raw = "https://dart.fss.or.kr/dsab007/main.do?textCrpNm=\(encoded)"
        case .kind:
            raw = "https://kind.krx.co.kr/disclosure/todaydisclosure.do"
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
