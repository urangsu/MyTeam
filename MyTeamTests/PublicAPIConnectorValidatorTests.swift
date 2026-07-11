import XCTest
@testable import MyTeam

final class SupertonicProsodyTextProcessorTests: XCTestCase {
    func testProductSpeechPreservesVisibleBubbleWording() {
        let visible = "먼저 확인했습니다. 지금 진행하겠습니다!"

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: nil,
            style: .friendly
        )

        XCTAssertEqual(spoken, visible)
    }

    func testProductSpeechPreservesLongVisibleBubbleWithoutTruncation() {
        let visible = String(repeating: "긴 업무 문장입니다. ", count: 30)

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: "agent_3",
            style: .careful
        )

        XCTAssertGreaterThan(visible.count, 200)
        XCTAssertEqual(spoken, visible)
    }

    func testProductSpeechPreservesWhitespaceAndPunctuation() {
        let visible = "첫 줄입니다.\n둘째 줄입니다!!  그대로 읽어주세요..."

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: "agent_2",
            style: .excited
        )

        XCTAssertEqual(spoken, visible)
    }

    func testStreamingSpeechChunkValidationDoesNotRewriteText() {
        let visible = "잠시만요!!  확인 중입니다...\n"

        XCTAssertEqual(SpeechManager.validatedTTSChunk(visible), visible)
        XCTAssertNil(SpeechManager.validatedTTSChunk("  !!!  "))
    }
}

final class SpeechRequestQueueTests: XCTestCase {
    func testQueuedSpeechRequestsRemainFIFO() async {
        let queue = SpeechRequestQueue()
        let first = SpeechRequest(id: UUID(), text: "첫 번째", agentID: "agent_1", characterName: "레오")
        let second = SpeechRequest(id: UUID(), text: "두 번째", agentID: "agent_2", characterName: "루나")

        let firstAccepted = await queue.enqueue(first, policy: .queue)
        let secondAccepted = await queue.enqueue(second, policy: .queue)
        let firstDequeued = await queue.next()
        XCTAssertTrue(firstAccepted)
        XCTAssertTrue(secondAccepted)
        XCTAssertEqual(firstDequeued, first)
        await queue.markFinished()
        let secondDequeued = await queue.next()
        XCTAssertEqual(secondDequeued, second)
    }

    func testDropIfBusyDoesNotReplaceActiveSpeech() async {
        let queue = SpeechRequestQueue()
        let active = SpeechRequest(id: UUID(), text: "재생 중", agentID: "agent_1", characterName: "레오")
        let dropped = SpeechRequest(id: UUID(), text: "겹친 대사", agentID: "agent_2", characterName: "루나")

        let activeAccepted = await queue.enqueue(active, policy: .queue)
        let activeDequeued = await queue.next()
        let droppedAccepted = await queue.enqueue(dropped, policy: .dropIfBusy)
        let snapshot = await queue.snapshot()
        XCTAssertTrue(activeAccepted)
        XCTAssertEqual(activeDequeued, active)
        XCTAssertFalse(droppedAccepted)
        XCTAssertEqual(snapshot.pendingCount, 0)
    }
}

final class BubbleSpeechSynthesizerTests: XCTestCase {
    func testBubbleSpeechGeneratesProceduralSyllableAudio() {
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        let samples = BubbleSpeechSynthesizer.synthesize(text: "뽀글뽀글 말하기!", config: config)

        XCTAssertGreaterThan(samples.count, 1_000)
        XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.01)
    }

    func testBubbleSpeechProfilesProduceDifferentTiming() {
        let cute = BubbleSpeechSynthesizer.synthesize(
            text: "안녕하세요",
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )
        let deep = BubbleSpeechSynthesizer.synthesize(
            text: "안녕하세요",
            config: BubbleSpeechConfig.from(profile: .deep, speed: 1.0)
        )

        XCTAssertNotEqual(cute.count, deep.count)
    }

    func testBubbleSpeechVowelColorsAffectWaveform() {
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        let bright = BubbleSpeechSynthesizer.synthesize(text: "가가가", config: config)
        let round = BubbleSpeechSynthesizer.synthesize(text: "고고고", config: config)

        XCTAssertEqual(bright.count, round.count)
        XCTAssertNotEqual(Array(bright.prefix(256)), Array(round.prefix(256)))
    }

    func testBubbleSpeechChopsExistingVoiceIntoShorterSyllableRhythm() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 2).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float(sin(2.0 * .pi * 440.0 * t) * 0.25)
        }

        let rendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "뽀글뽀글 말하기",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )

        XCTAssertLessThan(rendered.count, Int(Double(voiceSamples.count) * 0.95))
        XCTAssertGreaterThan(rendered.count, sampleRate / 20)
        XCTAssertGreaterThan(BubbleSpeechSynthesizer.meanAbsoluteDelta(rendered, voiceSamples), 0.002)
        XCTAssertGreaterThan(rendered.map { abs($0) }.max() ?? 0, 0.01)
        XCTAssertFalse(rendered.contains { !$0.isFinite })
    }

    func testBubbleSpeechGuideFailureDoesNotPassthroughVoiceSamples() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 4).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float(sin(2.0 * .pi * 330.0 * t) * 0.2)
        }

        let rendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: " !!!",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )

        XCTAssertTrue(rendered.isEmpty)
    }

    func testBubbleSpeechProfilesProduceDifferentChopperDurations() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float((sin(2.0 * .pi * 220.0 * t) + sin(2.0 * .pi * 660.0 * t) * 0.25) * 0.2)
        }

        let cute = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요 바로 해볼게요",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )
        let arcade = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요 바로 해볼게요",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .arcade, speed: 1.18)
        )

        XCTAssertFalse(cute.isEmpty)
        XCTAssertFalse(arcade.isEmpty)
        XCTAssertNotEqual(cute.count, arcade.count)
        XCTAssertGreaterThan(BubbleSpeechSynthesizer.meanAbsoluteDelta(cute, arcade), 0.001)
    }
}

final class PublicAPIConnectorValidatorTests: XCTestCase {
    func testNaverNewsValidationUsesClientHeadersAndURLComponents() throws {
        let request = PublicAPIValidationRequest(
            provider: .naverNews,
            fields: ["clientID": "id-123", "clientSecret": "secret-456"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.scheme, "https")
        XCTAssertEqual(built.url?.host, "openapi.naver.com")
        XCTAssertEqual(built.url?.path, "/v1/search/news.json")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Id"), "id-123")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Secret"), "secret-456")
        XCTAssertEqual(built.url?.queryValue("query"), "뉴스")
        XCTAssertEqual(built.url?.queryValue("display"), "1")
    }

    func testDARTValidationUsesDynamicDateAndCrtfcKeyQuery() throws {
        let clock = FixedPublicAPIClock(now: fixedDate("2026-06-03T00:30:00Z"))
        let request = PublicAPIValidationRequest(
            provider: .dartDisclosure,
            fields: ["apiKey": "dart-key"],
            clock: clock
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.host, "opendart.fss.or.kr")
        XCTAssertEqual(built.url?.path, "/api/list.json")
        XCTAssertEqual(built.url?.queryValue("crtfc_key"), "dart-key")
        XCTAssertEqual(built.url?.queryValue("bgn_de"), "20260602")
        XCTAssertEqual(built.url?.queryValue("page_count"), "1")
    }

    func testKMAValidationUsesDynamicBaseDateAndTime() throws {
        let clock = FixedPublicAPIClock(now: fixedDate("2026-06-03T00:30:00Z"))
        let request = PublicAPIValidationRequest(
            provider: .kmaWeather,
            fields: ["serviceKey": "kma-key"],
            clock: clock
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.host, "apis.data.go.kr")
        XCTAssertEqual(built.url?.queryValue("serviceKey"), "kma-key")
        XCTAssertEqual(built.url?.queryValue("base_date"), "20260603")
        XCTAssertEqual(built.url?.queryValue("base_time"), "0900")
    }

    func testKMABaseSlots_followProductSchedulesInKoreaTime() {
        let nowcastBeforeRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortNowcast,
            now: fixedDate("2026-06-02T15:05:00Z")
        )
        XCTAssertEqual(nowcastBeforeRelease.first, KMABaseSlot(date: "20260602", time: "2300"))

        let ultraBeforeRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortForecast,
            now: fixedDate("2026-06-03T00:40:00Z")
        )
        XCTAssertEqual(ultraBeforeRelease.first, KMABaseSlot(date: "20260603", time: "0830"))

        let ultraAfterRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortForecast,
            now: fixedDate("2026-06-03T00:50:00Z")
        )
        XCTAssertEqual(ultraAfterRelease.first, KMABaseSlot(date: "20260603", time: "0930"))

        let villageBeforeRelease = KMABaseTimePolicy.candidates(
            for: .villageForecast,
            now: fixedDate("2026-06-02T17:05:00Z")
        )
        XCTAssertEqual(villageBeforeRelease.first, KMABaseSlot(date: "20260602", time: "2300"))

        let villageAfterRelease = KMABaseTimePolicy.candidates(
            for: .villageForecast,
            now: fixedDate("2026-06-02T17:15:00Z")
        )
        XCTAssertEqual(villageAfterRelease.first, KMABaseSlot(date: "20260603", time: "0200"))
    }

    func testKMARegionMapper_neverFallsBackToSeoul() {
        XCTAssertNil(KMARegionGridMapper.resolve(nil))
        XCTAssertNil(KMARegionGridMapper.resolve(""))
        XCTAssertNil(KMARegionGridMapper.resolve("등록되지 않은 지역"))
        XCTAssertEqual(KMARegionGridMapper.resolve("광양 출장")?.name, "광양")
    }

    func testKoreanLawValidationUsesLawOCAndURLComponents() throws {
        let request = PublicAPIValidationRequest(
            provider: .koreanLaw,
            fields: ["lawOC": "law-key"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.scheme, "https")
        XCTAssertEqual(built.url?.host, "www.law.go.kr")
        XCTAssertEqual(built.url?.path, "/DRF/lawSearch.do")
        XCTAssertEqual(built.url?.queryValue("OC"), "law-key")
        XCTAssertEqual(built.url?.queryValue("target"), "law")
        XCTAssertEqual(built.url?.queryValue("type"), "JSON")
        XCTAssertEqual(built.url?.queryValue("query"), "개인정보")
    }

    func testNaverBodyParserRequiresItemsEvenWhenHTTPStatusIs200() throws {
        let empty = Data(#"{"lastBuildDate":"now","total":0,"start":1,"display":0,"items":[]}"#.utf8)
        let valid = Data(#"{"lastBuildDate":"now","total":1,"start":1,"display":1,"items":[{"title":"뉴스","originallink":"https://example.com","link":"https://example.com","description":"본문","pubDate":"Wed, 03 Jun 2026 09:00:00 +0900"}]}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .naverNews, data: empty))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .naverNews, data: valid))
    }

    func testDARTBodyParserRejectsErrorStatusEvenWhenHTTPStatusIs200() {
        let invalid = Data(#"{"status":"010","message":"등록되지 않은 키입니다."}"#.utf8)
        let valid = Data(#"{"status":"000","message":"정상","list":[{"corp_name":"테스트"}]}"#.utf8)
        let validNoData = Data(#"{"status":"013","message":"조회된 데이타가 없습니다."}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: invalid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: valid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: validNoData))
    }

    func testKMABodyParserRequiresNormalServiceResult() {
        let invalid = Data(#"{"response":{"header":{"resultCode":"03","resultMsg":"NO_DATA"}}}"#.utf8)
        let emptyBody = Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[]}}}}"#.utf8)
        let valid = Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[{"obsrValue":"20"}]}}}}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: invalid))
        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: emptyBody))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: valid))
    }

    func testKoreanLawBodyParserRequiresOfficialLawResult() {
        let invalid = Data(#"{"LawSearch":{"totalCnt":"0","law":[]}}"#.utf8)
        let valid = Data(#"{"LawSearch":{"totalCnt":"1","law":[{"법령명한글":"개인정보 보호법","법령ID":"011357","법령일련번호":"123456"}]}}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .koreanLaw, data: invalid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .koreanLaw, data: valid))
    }

    func testKoreanLawDirectConnectorBuildsSearchRequest() throws {
        let request = KoreanLawSearchRequest(query: "개인정보", lawName: nil, article: nil)

        let built = try KoreanLawDirectConnector.makeSearchRequest(request, lawOC: "law-key")

        XCTAssertEqual(built.url?.host, "www.law.go.kr")
        XCTAssertEqual(built.url?.path, "/DRF/lawSearch.do")
        XCTAssertEqual(built.url?.queryValue("OC"), "law-key")
        XCTAssertEqual(built.url?.queryValue("target"), "law")
        XCTAssertEqual(built.url?.queryValue("type"), "JSON")
        XCTAssertEqual(built.url?.queryValue("query"), "개인정보")
    }

    func testKoreanLawDirectConnectorKeepsSearchResultsPartial() {
        let data = Data(#"{"LawSearch":{"totalCnt":"1","law":[{"법령명한글":"개인정보 보호법","법령ID":"011357","시행일자":"20240315"}]}}"#.utf8)

        let results = KoreanLawDirectConnector.parseSearchResponse(data)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].status, .partial)
        XCTAssertEqual(results[0].verificationStatus, "partial")
        XCTAssertEqual(results[0].lawName, "개인정보 보호법")
        XCTAssertEqual(results[0].effectiveDate, "20240315")
        XCTAssertFalse(results[0].sources.isEmpty)
        XCTAssertTrue(results[0].disclaimer.contains("법률 자문이 아닌"))
    }

    func testKoreanLawCitationVerificationFailsWhenExpectedArticleIsMissing() {
        let result = KoreanLawResult(
            status: .partial,
            lawName: "개인정보 보호법",
            article: nil,
            effectiveDate: "20240315",
            officialSourceURL: URL(string: "https://www.law.go.kr/법령?id=011357"),
            verificationStatus: "partial",
            summary: "공식 법령 검색 결과입니다.",
            mismatchDetails: [],
            sources: [],
            disclaimer: KoreanLawDirectConnector.disclaimer
        )
        let request = KoreanLawCitationVerificationRequest(
            citationText: "개인정보 보호법 제1조",
            expectedLawName: "개인정보 보호법",
            expectedArticle: "제1조",
            expectedParagraph: nil,
            expectedItem: nil,
            expectedEffectiveDate: nil
        )

        let verified = KoreanLawDirectConnector.verifyCitation(request, against: result)

        XCTAssertEqual(verified.status, .failed)
        XCTAssertTrue(verified.mismatchDetails.contains { $0.contains("조문 누락") })
    }

    func testKoreanLawCitationVerificationFailsWithoutOfficialSource() {
        let result = KoreanLawResult(
            status: .partial,
            lawName: "개인정보 보호법",
            article: "제1조",
            effectiveDate: "20240315",
            officialSourceURL: nil,
            verificationStatus: "partial",
            summary: "공식 법령 검색 결과입니다.",
            mismatchDetails: [],
            sources: [],
            disclaimer: KoreanLawDirectConnector.disclaimer
        )
        let request = KoreanLawCitationVerificationRequest(
            citationText: "개인정보 보호법 제1조",
            expectedLawName: "개인정보 보호법",
            expectedArticle: "제1조",
            expectedParagraph: nil,
            expectedItem: nil,
            expectedEffectiveDate: "20240315"
        )

        let verified = KoreanLawDirectConnector.verifyCitation(request, against: result)

        XCTAssertEqual(verified.status, .failed)
        XCTAssertTrue(verified.mismatchDetails.contains { $0.contains("공식 출처 URL 누락") })
    }

    private func fixedDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }
}

final class DARTCompanyIndexTests: XCTestCase {
    private let entries = [
        DARTCompanyIndexEntry(
            corpCode: "00126380",
            corpName: "삼성전자(주)",
            stockCode: "005930",
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00164779",
            corpName: "에스케이하이닉스(주)",
            stockCode: "000660",
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00900001",
            corpName: "동일상사",
            stockCode: nil,
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00900002",
            corpName: "동일상사(주)",
            stockCode: nil,
            modifyDate: "20260701"
        )
    ]

    func testResolvesAnyIndexedCompanyByStockCode() {
        let result = index.resolve(input: "000660", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "00164779")
        XCTAssertEqual(result.stockCode, "000660")
        XCTAssertEqual(result.resolutionSource, .officialStockCodeIndex)
    }

    func testResolvesNormalizedOfficialCompanyName() {
        let result = index.resolve(input: "삼성전자", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "00126380")
        XCTAssertEqual(result.resolutionSource, .officialCompanyNameIndex)
    }

    func testAcceptsExplicitCorpCodeWithoutChoosingAnotherCompany() {
        let result = index.resolve(input: "12345678", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "12345678")
        XCTAssertEqual(result.resolutionSource, .directCorpCode)
    }

    func testAmbiguousCompanyNameDoesNotAutoResolveFirstCandidate() {
        let result = index.resolve(input: "동일상사", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertNil(result.corpCode)
        XCTAssertEqual(result.resolutionSource, .ambiguous)
        XCTAssertEqual(result.candidates.count, 2)
    }

    func testPartialNameOnlySuggestsCandidates() {
        let result = index.resolve(input: "하이닉스", indexUpdatedAt: nil, isIndexStale: true)

        XCTAssertNil(result.corpCode)
        XCTAssertEqual(result.resolutionSource, .ambiguous)
        XCTAssertEqual(result.candidates.first?.stockCode, "000660")
        XCTAssertTrue(result.isIndexStale)
    }

    private var index: DARTCompanyIndex {
        DARTCompanyIndex(entries: entries)
    }
}

private struct FixedPublicAPIClock: PublicAPIClock {
    let now: Date
    let timeZone = TimeZone(identifier: "Asia/Seoul")!
}

private extension URL {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}
