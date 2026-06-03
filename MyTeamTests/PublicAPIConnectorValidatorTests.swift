import XCTest
@testable import MyTeam

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
        XCTAssertEqual(built.url?.queryValue("base_time"), "0800")
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
        let valid = Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[{"obsrValue":"20"}]}}}}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: invalid))
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

    func testKoreanLawDirectConnectorParsesOfficialSources() {
        let data = Data(#"{"LawSearch":{"totalCnt":"1","law":[{"법령명한글":"개인정보 보호법","법령ID":"011357","시행일자":"20240315"}]}}"#.utf8)

        let results = KoreanLawDirectConnector.parseSearchResponse(data)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].status, .verified)
        XCTAssertEqual(results[0].lawName, "개인정보 보호법")
        XCTAssertEqual(results[0].effectiveDate, "20240315")
        XCTAssertFalse(results[0].sources.isEmpty)
        XCTAssertTrue(results[0].disclaimer.contains("법률 자문이 아닌"))
    }

    private func fixedDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
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
