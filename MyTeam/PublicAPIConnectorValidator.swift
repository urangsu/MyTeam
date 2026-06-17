import Foundation

protocol PublicAPIClock: Sendable {
    var now: Date { get }
    var timeZone: TimeZone { get }
}

struct SystemPublicAPIClock: PublicAPIClock {
    nonisolated init() {}

    var now: Date { Date() }
    let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
}

struct PublicAPIValidationRequest: Sendable {
    let provider: ExternalProvider
    let fields: [String: String]
    let clock: any PublicAPIClock

    init(
        provider: ExternalProvider,
        fields: [String: String],
        clock: any PublicAPIClock = SystemPublicAPIClock()
    ) {
        self.provider = provider
        self.fields = fields
        self.clock = clock
    }
}

enum PublicAPIConnectorValidator {
    static func makeRequest(for request: PublicAPIValidationRequest) throws -> URLRequest {
        switch request.provider {
        case .naverNews:
            return try makeNaverNewsRequest(fields: request.fields)
        case .dartDisclosure:
            return try makeDARTRequest(fields: request.fields, clock: request.clock)
        case .kmaWeather:
            return try makeKMARequest(fields: request.fields, clock: request.clock)
        case .koreanLaw:
            return try makeKoreanLawRequest(fields: request.fields)
        case .openAI, .gemini, .anthropic, .openRouter:
            throw ConnectorFailureCode.providerUnavailable
        }
    }

    static func validate(
        _ request: PublicAPIValidationRequest,
        session: URLSession = .shared
    ) async -> CredentialTestResult {
        do {
            let urlRequest = try makeRequest(for: request)
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                return CredentialTestResult(provider: request.provider, success: false, failureCode: .networkError, message: "응답을 확인하지 못했습니다.")
            }
            guard (200..<300).contains(http.statusCode) else {
                return CredentialTestResult(provider: request.provider, success: false, failureCode: failureCode(statusCode: http.statusCode), message: "\(request.provider.displayName) 연결 확인에 실패했습니다.")
            }
            guard bodyIndicatesSuccess(provider: request.provider, data: data) else {
                return CredentialTestResult(provider: request.provider, success: false, failureCode: .responseParseFailed, message: "\(request.provider.displayName) 응답 본문이 정상 상태를 나타내지 않습니다.")
            }
            return CredentialTestResult(provider: request.provider, success: true, failureCode: nil, message: "\(request.provider.displayName) 실제 연결 확인을 통과했습니다.")
        } catch let code as ConnectorFailureCode {
            return CredentialTestResult(provider: request.provider, success: false, failureCode: code, message: code.userMessage(for: request.provider))
        } catch {
            return CredentialTestResult(provider: request.provider, success: false, failureCode: .networkError, message: error.localizedDescription)
        }
    }

    static func bodyIndicatesSuccess(provider: ExternalProvider, data: Data) -> Bool {
        switch provider {
        case .naverNews:
            return parseNaverNews(data)
        case .dartDisclosure:
            return parseDART(data)
        case .kmaWeather:
            return parseKMA(data)
        case .koreanLaw:
            return parseKoreanLaw(data)
        case .openAI, .gemini, .anthropic, .openRouter:
            return false
        }
    }

    private static func makeNaverNewsRequest(fields: [String: String]) throws -> URLRequest {
        guard
            let clientID = trimmed(fields["clientID"]),
            let clientSecret = trimmed(fields["clientSecret"])
        else {
            throw ConnectorFailureCode.missingAPIKey
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "openapi.naver.com"
        components.path = "/v1/search/news.json"
        components.queryItems = [
            URLQueryItem(name: "query", value: "뉴스"),
            URLQueryItem(name: "display", value: "1"),
            URLQueryItem(name: "start", value: "1"),
            URLQueryItem(name: "sort", value: "date")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }

        var request = URLRequest(url: url)
        request.setValue(clientID, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")
        return request
    }

    private static func makeDARTRequest(fields: [String: String], clock: any PublicAPIClock) throws -> URLRequest {
        guard let apiKey = trimmed(fields["apiKey"]) else {
            throw ConnectorFailureCode.missingAPIKey
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "opendart.fss.or.kr"
        components.path = "/api/company.json"
        components.queryItems = [
            URLQueryItem(name: "crtfc_key", value: apiKey),
            URLQueryItem(name: "corp_code", value: "00126380")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }
        return URLRequest(url: url)
    }

    private static func makeKMARequest(fields: [String: String], clock: any PublicAPIClock) throws -> URLRequest {
        guard let serviceKey = trimmed(fields["serviceKey"]) else {
            throw ConnectorFailureCode.missingAPIKey
        }
        let base = kmaBaseDateTime(clock: clock)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apis.data.go.kr"
        components.path = "/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst"
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: serviceKey),
            URLQueryItem(name: "numOfRows", value: "1"),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "dataType", value: "JSON"),
            URLQueryItem(name: "base_date", value: base.date),
            URLQueryItem(name: "base_time", value: base.time),
            URLQueryItem(name: "nx", value: "60"),
            URLQueryItem(name: "ny", value: "127")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }
        return URLRequest(url: url)
    }

    private static func makeKoreanLawRequest(fields: [String: String]) throws -> URLRequest {
        guard let lawOC = trimmed(fields["lawOC"]) else {
            throw ConnectorFailureCode.missingAPIKey
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.law.go.kr"
        components.path = "/DRF/lawSearch.do"
        components.queryItems = [
            URLQueryItem(name: "OC", value: lawOC),
            URLQueryItem(name: "target", value: "law"),
            URLQueryItem(name: "type", value: "JSON"),
            URLQueryItem(name: "query", value: "개인정보"),
            URLQueryItem(name: "display", value: "1")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }
        return URLRequest(url: url)
    }

    private static func parseNaverNews(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = object["items"] as? [[String: Any]]
        else {
            return false
        }
        return !items.isEmpty
    }

    private static func parseDART(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        let status = object["status"] as? String
        if object["corp_name"] != nil || object["stock_code"] != nil {
            return status == "000"
                && (object["corp_name"] as? String)?.isEmpty == false
                && object["stock_code"] as? String == "005930"
        }
        return status == "000" || status == "013"
    }

    private static func parseKMA(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let response = object["response"] as? [String: Any],
            let header = response["header"] as? [String: Any],
            let resultCode = header["resultCode"] as? String,
            let body = response["body"] as? [String: Any],
            let items = body["items"] as? [String: Any]
        else {
            return false
        }
        guard resultCode == "00" else { return false }
        if let itemArray = items["item"] as? [[String: Any]] {
            return !itemArray.isEmpty
        }
        if let singleItem = items["item"] as? [String: Any] {
            return !singleItem.isEmpty
        }
        return false
    }

    private static func parseKoreanLaw(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let search = object["LawSearch"] as? [String: Any]
        else {
            return false
        }

        let totalCount: Int
        if let value = search["totalCnt"] as? Int {
            totalCount = value
        } else if let value = search["totalCnt"] as? String, let parsed = Int(value) {
            totalCount = parsed
        } else {
            totalCount = 0
        }

        guard totalCount > 0 else { return false }

        if let laws = search["law"] as? [[String: Any]] {
            return laws.contains { law in
                law["법령명한글"] != nil && (law["법령ID"] != nil || law["법령일련번호"] != nil)
            }
        }
        if let law = search["law"] as? [String: Any] {
            return law["법령명한글"] != nil && (law["법령ID"] != nil || law["법령일련번호"] != nil)
        }
        return false
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func failureCode(statusCode: Int) -> ConnectorFailureCode {
        switch statusCode {
        case 401:
            return .invalidAPIKey
        case 403:
            return .permissionDenied
        case 429:
            return .rateLimited
        case 500...599:
            return .providerUnavailable
        default:
            return .responseParseFailed
        }
    }

    private static func yyyymmdd(daysBefore: Int, clock: any PublicAPIClock) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = clock.timeZone
        let date = calendar.date(byAdding: .day, value: -daysBefore, to: clock.now) ?? clock.now
        return dateFormatter(timeZone: clock.timeZone).string(from: date)
    }

    private static func kmaBaseDateTime(clock: any PublicAPIClock) -> (date: String, time: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = clock.timeZone
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: clock.now)
        if (components.minute ?? 0) < 45 {
            let previousHour = calendar.date(byAdding: .hour, value: -1, to: clock.now) ?? clock.now
            components = calendar.dateComponents([.year, .month, .day, .hour], from: previousHour)
        }
        let date = calendar.date(from: components) ?? clock.now
        let hour = components.hour ?? 0
        return (dateFormatter(timeZone: clock.timeZone).string(from: date), String(format: "%02d00", hour))
    }

    private static func dateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }
}

struct NaverNewsDirectItem: Sendable, Equatable {
    let title: String
    let description: String
    let link: URL
    let originalLink: URL?
    let publishedAt: Date?

    nonisolated var sourceURL: URL {
        originalLink ?? link
    }

    nonisolated var sourceDomain: String {
        sourceURL.host ?? "unknown"
    }
}

struct DARTDisclosureDirectItem: Sendable, Equatable {
    let corporationName: String
    let corpCode: String?
    let stockCode: String?
    let reportName: String
    let receiptNumber: String
    let receiptDate: String
    let submitterName: String?
    let remark: String?
    let sourceURL: URL
}

struct KMAWeatherDirectObservation: Sendable, Equatable {
    let category: String
    let value: String
    let baseDate: String
    let baseTime: String
}

enum NaverNewsDirectConnector {
    static func search(
        query: String,
        clientID: String,
        clientSecret: String,
        display: Int = 5,
        start: Int = 1,
        sort: String = "date",
        session: URLSession = .shared
    ) async throws -> [NaverNewsDirectItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { throw ConnectorFailureCode.responseParseFailed }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "openapi.naver.com"
        components.path = "/v1/search/news.json"
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "display", value: String(min(max(display, 1), 10))),
            URLQueryItem(name: "start", value: String(max(start, 1))),
            URLQueryItem(name: "sort", value: sort == "sim" ? "sim" : "date")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }

        var request = URLRequest(url: url)
        request.setValue(clientID.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-Naver-Client-Secret")

        let (data, response) = try await session.data(for: request)
        try validateDirectHTTP(response)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = object["items"] as? [[String: Any]]
        else {
            throw ConnectorFailureCode.responseParseFailed
        }

        var seen = Set<String>()
        return items.compactMap { item in
            guard
                let title = item["title"] as? String,
                let linkString = item["link"] as? String,
                let link = URL(string: linkString)
            else { return nil }
            let originalLink = (item["originallink"] as? String).flatMap(URL.init(string:))
            let key = (originalLink ?? link).absoluteString
            guard seen.insert(key).inserted else { return nil }
            return NaverNewsDirectItem(
                title: cleanHTML(title),
                description: cleanHTML(item["description"] as? String ?? ""),
                link: link,
                originalLink: originalLink,
                publishedAt: parseNaverPubDate(item["pubDate"] as? String)
            )
        }
    }

    private static func parseNaverPubDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: raw)
    }
}

nonisolated enum MyTeamBasicLookupProxyConfig {
    nonisolated static let defaultBaseURLString = "https://late-waterfall-c95c.urange.workers.dev"
    nonisolated static let userDefaultsKey = "myteam.basicLookupProxy.baseURL"

    nonisolated static var baseURL: URL? {
        let override = UserDefaults.standard.string(forKey: userDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty {
            return URL(string: override)
        }
        return URL(string: defaultBaseURLString)
    }
}

nonisolated struct MyTeamProxyHealth: Decodable, Sendable, Equatable {
    let ok: Bool
    let service: String?
    let version: String?
}

nonisolated struct MyTeamProxyNewsSearchResponse: Decodable, Sendable, Equatable {
    let ok: Bool
    let provider: String
    let query: String
    let count: Int
    let elapsedMs: Int?
    let items: [MyTeamProxyNewsItem]
}

nonisolated struct MyTeamProxyNewsItem: Decodable, Identifiable, Sendable, Equatable {
    nonisolated var id: String { dedupeKey }

    let title: String
    let description: String
    let originallink: String?
    let link: String?
    let pubDate: String?

    nonisolated var cleanedTitle: String {
        cleanHTML(title)
    }

    nonisolated var cleanedDescription: String {
        cleanHTML(description)
    }

    nonisolated var sourceURL: URL? {
        if let originallink, let url = URL(string: originallink) { return url }
        if let link, let url = URL(string: link) { return url }
        return nil
    }

    nonisolated var sourceDomain: String {
        sourceURL?.host ?? "unknown"
    }

    nonisolated var dedupeKey: String {
        if let sourceURL {
            return sourceURL.absoluteString
        }
        return cleanedTitle
    }
}

nonisolated struct MyTeamProxyDARTSearchResponse: Decodable, Sendable, Equatable {
    let ok: Bool
    let provider: String
    let count: Int?
    let elapsedMs: Int?
    let items: [MyTeamProxyDARTItem]
}

nonisolated struct MyTeamProxyDARTItem: Decodable, Identifiable, Sendable, Equatable {
    nonisolated var id: String { receiptNo }

    let corpName: String
    let corpCode: String?
    let stockCode: String?
    let corpClass: String?
    let reportName: String
    let receiptNo: String
    let receiptDate: String
    let submitter: String?
    let remark: String?
    let sourceURL: String
    let dedupeKey: String?
}

nonisolated struct MyTeamProxyKMAResponse: Decodable, Sendable, Equatable {
    let ok: Bool
    let provider: String
    let type: String
    let grid: MyTeamProxyKMAGrid
    let baseDate: String
    let baseTime: String
    let elapsedMs: Int?
    let items: [MyTeamProxyKMAItem]
}

nonisolated struct MyTeamProxyKMAGrid: Decodable, Sendable, Equatable {
    let nx: Int
    let ny: Int
}

nonisolated struct MyTeamProxyKMAItem: Decodable, Identifiable, Sendable, Equatable {
    nonisolated var id: String {
        [
            category,
            baseDate,
            baseTime,
            forecastDate ?? "",
            forecastTime ?? ""
        ].joined(separator: "-")
    }

    let category: String
    let label: String
    let value: String
    let unit: String
    let baseDate: String
    let baseTime: String
    let forecastDate: String?
    let forecastTime: String?
}

nonisolated struct MyTeamProxyLawSearchResponse: Decodable, Sendable, Equatable {
    let ok: Bool
    let provider: String
    let query: String
    let count: Int?
    let elapsedMs: Int?
    let items: [MyTeamProxyLawItem]
    let notice: String?
}

nonisolated struct MyTeamProxyLawItem: Decodable, Identifiable, Sendable, Equatable {
    nonisolated var id: String { lawId }

    let lawName: String
    let lawId: String
    let promulgationDate: String?
    let enforcementDate: String?
    let sourceURL: String
    let dedupeKey: String?
    let status: String?
}

nonisolated struct MyTeamProxyFailureResponse: Decodable, Sendable, Equatable {
    let ok: Bool
    let error: String?
    let provider: String?
    let message: String?
    let status: Int?
    let stage: String?
    let providerStatus: String?
    let classification: String?
    let retryable: Bool?
    let mergeGate: String?
}

nonisolated enum MyTeamProxyError: Error, LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case providerUnavailable(MyTeamProxyFailureResponse)
    case decodingFailed
    case queryTooShort
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "기본 조회 서버 주소를 확인하지 못했습니다."
        case .invalidResponse:
            return "기본 조회 서버 응답을 확인하지 못했습니다."
        case .httpStatus(let status):
            return "기본 조회 서버가 HTTP \(status)을 반환했습니다."
        case .providerUnavailable(let failure):
            return failure.userFacingMessage
        case .decodingFailed:
            return "기본 조회 서버 응답 형식을 해석하지 못했습니다."
        case .queryTooShort:
            return "검색어는 두 글자 이상이어야 합니다."
        case .noResults:
            return "기본 조회 결과가 없습니다."
        }
    }
}

extension MyTeamProxyFailureResponse {
    nonisolated var userFacingMessage: String {
        let providerKey = provider?.lowercased() ?? ""
        if providerKey == "dart", classification == "provider_reachability_failure" {
            return "DART 제공기관 응답 지연으로 공시 조회를 완료하지 못했습니다. 잠시 후 다시 시도하거나, 기본 조회 상태 또는 개인 DART API 키 연결 상태를 확인하세요."
        }
        if providerKey == "kma", error == "invalid_credentials" {
            return "기상청 조회 인증 설정을 확인해야 합니다. 관리자 기본 조회 키 또는 개인 API 키 설정을 확인하세요."
        }
        return message ?? "기본 조회 서버가 요청을 완료하지 못했습니다."
    }
}

actor MyTeamBasicLookupProxyClient {
    static let shared = MyTeamBasicLookupProxyClient()

    func health(session: URLSession = .shared) async throws -> MyTeamProxyHealth {
        guard let baseURL = MyTeamBasicLookupProxyConfig.baseURL else {
            throw MyTeamProxyError.invalidBaseURL
        }
        let url = baseURL.appending(path: "health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        try validateProxyHTTP(response)
        do {
            let health = try JSONDecoder().decode(MyTeamProxyHealth.self, from: data)
            guard health.ok else {
                throw MyTeamProxyError.providerUnavailable(
                    MyTeamProxyFailureResponse(
                        ok: false,
                        error: "provider_unavailable",
                        provider: nil,
                        message: "기본 조회 서버가 준비되지 않았습니다.",
                        status: nil,
                        stage: nil,
                        providerStatus: nil,
                        classification: nil,
                        retryable: nil,
                        mergeGate: nil
                    )
                )
            }
            return health
        } catch let error as MyTeamProxyError {
            throw error
        } catch {
            throw MyTeamProxyError.decodingFailed
        }
    }

    func searchNews(
        query: String,
        display: Int = 10,
        session: URLSession = .shared
    ) async throws -> MyTeamProxyNewsSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { throw MyTeamProxyError.queryTooShort }
        guard let baseURL = MyTeamBasicLookupProxyConfig.baseURL else {
            throw MyTeamProxyError.invalidBaseURL
        }

        var components = URLComponents(url: baseURL.appending(path: "news/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "display", value: String(min(max(display, 1), 20)))
        ]
        guard let url = components?.url else { throw MyTeamProxyError.invalidBaseURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        try validateProxyHTTP(response)
        do {
            let decoded = try JSONDecoder().decode(MyTeamProxyNewsSearchResponse.self, from: data)
            guard decoded.ok else {
                throw MyTeamProxyError.providerUnavailable(
                    MyTeamProxyFailureResponse(
                        ok: false,
                        error: "provider_unavailable",
                        provider: "naver-news",
                        message: "네이버 뉴스 기본 조회가 준비되지 않았습니다.",
                        status: nil,
                        stage: nil,
                        providerStatus: nil,
                        classification: nil,
                        retryable: nil,
                        mergeGate: nil
                    )
                )
            }
            return decoded
        } catch let error as MyTeamProxyError {
            throw error
        } catch {
            throw MyTeamProxyError.decodingFailed
        }
    }

    func searchDARTDisclosures(
        query: String,
        corpCode: String? = nil,
        daysBack: Int = 7,
        display: Int = 10,
        session: URLSession = .shared
    ) async throws -> MyTeamProxyDARTSearchResponse {
        guard let baseURL = MyTeamBasicLookupProxyConfig.baseURL else {
            throw MyTeamProxyError.invalidBaseURL
        }
        var components = URLComponents(url: baseURL.appending(path: "dart/recent"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "days", value: String(min(max(daysBack, 1), 30))),
            URLQueryItem(name: "display", value: String(min(max(display, 1), 20)))
        ]
        if let corpCode, !corpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "corpCode", value: corpCode.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else {
            queryItems.append(URLQueryItem(name: "corpName", value: query.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw MyTeamProxyError.invalidBaseURL }

        return try await requestProxy(url: url, session: session, responseType: MyTeamProxyDARTSearchResponse.self)
    }

    func fetchKMANowcast(
        nx: Int,
        ny: Int,
        session: URLSession = .shared
    ) async throws -> MyTeamProxyKMAResponse {
        try await fetchKMA(path: "weather/kma/nowcast", nx: nx, ny: ny, session: session)
    }

    func fetchKMAForecast(
        nx: Int,
        ny: Int,
        session: URLSession = .shared
    ) async throws -> MyTeamProxyKMAResponse {
        try await fetchKMA(path: "weather/kma/forecast", nx: nx, ny: ny, session: session)
    }

    func searchKoreanLaw(
        query: String,
        display: Int = 10,
        session: URLSession = .shared
    ) async throws -> MyTeamProxyLawSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { throw MyTeamProxyError.queryTooShort }
        guard let baseURL = MyTeamBasicLookupProxyConfig.baseURL else {
            throw MyTeamProxyError.invalidBaseURL
        }
        var components = URLComponents(url: baseURL.appending(path: "law/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "display", value: String(min(max(display, 1), 20)))
        ]
        guard let url = components?.url else { throw MyTeamProxyError.invalidBaseURL }

        return try await requestProxy(url: url, session: session, responseType: MyTeamProxyLawSearchResponse.self)
    }

    private func validateProxyHTTP(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MyTeamProxyError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MyTeamProxyError.httpStatus(httpResponse.statusCode)
        }
    }

    private func fetchKMA(
        path: String,
        nx: Int,
        ny: Int,
        session: URLSession
    ) async throws -> MyTeamProxyKMAResponse {
        guard let baseURL = MyTeamBasicLookupProxyConfig.baseURL else {
            throw MyTeamProxyError.invalidBaseURL
        }
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "nx", value: String(nx)),
            URLQueryItem(name: "ny", value: String(ny))
        ]
        guard let url = components?.url else { throw MyTeamProxyError.invalidBaseURL }

        return try await requestProxy(url: url, session: session, responseType: MyTeamProxyKMAResponse.self)
    }

    private func requestProxy<T: Decodable>(
        url: URL,
        session: URLSession,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        try validateProxyHTTP(response)
        do {
            if
                let failure = try? JSONDecoder().decode(MyTeamProxyFailureResponse.self, from: data),
                failure.ok == false
            {
                if failure.error == "no_results" {
                    throw MyTeamProxyError.noResults
                }
                throw MyTeamProxyError.providerUnavailable(failure)
            }
            return try JSONDecoder().decode(responseType, from: data)
        } catch let error as MyTeamProxyError {
            throw error
        } catch {
            throw MyTeamProxyError.decodingFailed
        }
    }
}

extension MyTeamProxyNewsSearchResponse {
    nonisolated var directItems: [NaverNewsDirectItem] {
        var seen = Set<String>()
        return items.compactMap { item in
            let title = item.cleanedTitle
            guard !title.isEmpty else { return nil }
            guard let sourceURL = item.sourceURL else { return nil }
            let dedupeKey = item.dedupeKey
            guard seen.insert(dedupeKey).inserted else { return nil }
            return NaverNewsDirectItem(
                title: title,
                description: item.cleanedDescription,
                link: sourceURL,
                originalLink: URL(string: item.originallink ?? ""),
                publishedAt: parseNaverProxyPubDate(item.pubDate)
            )
        }
    }

    nonisolated private func parseNaverProxyPubDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: raw)
    }
}

extension MyTeamProxyDARTSearchResponse {
    nonisolated var directItems: [DARTDisclosureDirectItem] {
        items.compactMap { item in
            guard let url = URL(string: item.sourceURL) else { return nil }
            return DARTDisclosureDirectItem(
                corporationName: item.corpName,
                corpCode: item.corpCode,
                stockCode: item.stockCode,
                reportName: item.reportName,
                receiptNumber: item.receiptNo,
                receiptDate: item.receiptDate,
                submitterName: item.submitter,
                remark: item.remark,
                sourceURL: url
            )
        }
    }
}

extension MyTeamProxyKMAResponse {
    nonisolated var directObservations: [KMAWeatherDirectObservation] {
        items.map {
            KMAWeatherDirectObservation(
                category: $0.category,
                value: $0.value,
                baseDate: $0.baseDate,
                baseTime: $0.baseTime
            )
        }
    }
}

extension MyTeamProxyLawSearchResponse {
    nonisolated var directResults: [KoreanLawResult] {
        items.compactMap { item in
            guard let url = URL(string: item.sourceURL) else { return nil }
            let source = KoreanLawSource(title: item.lawName, url: url, publisher: "국가법령정보센터")
            return KoreanLawResult(
                status: .partial,
                lawName: item.lawName,
                article: nil,
                effectiveDate: item.enforcementDate,
                officialSourceURL: url,
                verificationStatus: item.status ?? "partial",
                summary: "공식 법령 검색 결과입니다. 법률 자문이 아닙니다.",
                mismatchDetails: [],
                sources: [source],
                disclaimer: KoreanLawDirectConnector.disclaimer
            )
        }
    }
}

enum DARTDisclosureDirectConnector {
    static func recentDisclosures(
        corpCode: String,
        apiKey: String,
        daysBack: Int = 30,
        pageCount: Int = 20,
        session: URLSession = .shared,
        clock: any PublicAPIClock = SystemPublicAPIClock()
    ) async throws -> [DARTDisclosureDirectItem] {
        let trimmedCorpCode = corpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCorpCode.range(of: #"^\d{8}$"#, options: .regularExpression) != nil else {
            throw ConnectorFailureCode.responseParseFailed
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "opendart.fss.or.kr"
        components.path = "/api/list.json"
        components.queryItems = [
            URLQueryItem(name: "crtfc_key", value: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "corp_code", value: trimmedCorpCode),
            URLQueryItem(name: "bgn_de", value: directDateString(daysBefore: max(daysBack, 1), clock: clock)),
            URLQueryItem(name: "end_de", value: directDateString(daysBefore: 0, clock: clock)),
            URLQueryItem(name: "sort", value: "date"),
            URLQueryItem(name: "sort_mth", value: "desc"),
            URLQueryItem(name: "page_no", value: "1"),
            URLQueryItem(name: "page_count", value: String(min(max(pageCount, 1), 100)))
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        try validateDirectHTTP(response)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectorFailureCode.responseParseFailed
        }
        let status = object["status"] as? String
        guard status == "000" else {
            if status == "013" { return [] }
            throw dartFailureCode(status)
        }
        guard let list = object["list"] as? [[String: Any]] else { return [] }
        return Array(list.compactMap(parseItem).prefix(min(max(pageCount, 1), 100)))
    }

    private static func parseItem(_ item: [String: Any]) -> DARTDisclosureDirectItem? {
        guard
            let corpName = item["corp_name"] as? String,
            let reportName = item["report_nm"] as? String,
            let receiptNumber = item["rcept_no"] as? String,
            let receiptDate = item["rcept_dt"] as? String,
            let sourceURL = URL(string: "https://dart.fss.or.kr/dsaf001/main.do?rcpNo=\(receiptNumber)")
        else { return nil }
        return DARTDisclosureDirectItem(
            corporationName: corpName,
            corpCode: item["corp_code"] as? String,
            stockCode: item["stock_code"] as? String,
            reportName: reportName,
            receiptNumber: receiptNumber,
            receiptDate: receiptDate,
            submitterName: item["flr_nm"] as? String,
            remark: item["rm"] as? String,
            sourceURL: sourceURL
        )
    }

    private static func dartFailureCode(_ status: String?) -> ConnectorFailureCode {
        switch status {
        case "010", "011", "901":
            return .invalidAPIKey
        case "012":
            return .permissionDenied
        case "020":
            return .quotaExceeded
        case "021", "100", "101":
            return .responseParseFailed
        case "800", "900":
            return .providerUnavailable
        default:
            return .responseParseFailed
        }
    }
}

enum KMAWeatherDirectConnector {
    static func ultraShortNowcast(
        serviceKey: String,
        nx: Int = 60,
        ny: Int = 127,
        session: URLSession = .shared,
        clock: any PublicAPIClock = SystemPublicAPIClock()
    ) async throws -> [KMAWeatherDirectObservation] {
        let base = directKMABaseDateTime(clock: clock)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apis.data.go.kr"
        components.path = "/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst"
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "numOfRows", value: "20"),
            URLQueryItem(name: "dataType", value: "JSON"),
            URLQueryItem(name: "base_date", value: base.date),
            URLQueryItem(name: "base_time", value: base.time),
            URLQueryItem(name: "nx", value: String(nx)),
            URLQueryItem(name: "ny", value: String(ny))
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }

        let (data, response) = try await session.data(for: URLRequest(url: url))
        try validateDirectHTTP(response)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let responseObject = object["response"] as? [String: Any],
            let header = responseObject["header"] as? [String: Any],
            header["resultCode"] as? String == "00",
            let body = responseObject["body"] as? [String: Any],
            let itemsContainer = body["items"] as? [String: Any],
            let items = itemsContainer["item"] as? [[String: Any]]
        else {
            throw ConnectorFailureCode.responseParseFailed
        }

        let observations = items.compactMap { item -> KMAWeatherDirectObservation? in
            guard
                let category = item["category"] as? String,
                let value = item["obsrValue"] as? String,
                let baseDate = item["baseDate"] as? String,
                let baseTime = item["baseTime"] as? String
            else { return nil }
            return KMAWeatherDirectObservation(category: category, value: value, baseDate: baseDate, baseTime: baseTime)
        }
        guard !observations.isEmpty else { throw ConnectorFailureCode.responseParseFailed }
        return observations
    }
}

extension KoreanLawDirectConnector {
    static func search(
        _ request: KoreanLawSearchRequest,
        lawOC: String,
        session: URLSession = .shared
    ) async throws -> [KoreanLawResult] {
        let urlRequest = try makeSearchRequest(request, lawOC: lawOC)
        let (data, response) = try await session.data(for: urlRequest)
        try validateDirectHTTP(response)
        return parseSearchResponse(data)
    }
}

private func validateDirectHTTP(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw ConnectorFailureCode.networkError
    }
    switch httpResponse.statusCode {
    case 200:
        return
    case 401, 403:
        throw ConnectorFailureCode.invalidAPIKey
    case 429:
        throw ConnectorFailureCode.rateLimited
    case 500...599:
        throw ConnectorFailureCode.providerUnavailable
    default:
        throw ConnectorFailureCode.networkError
    }
}

nonisolated private func cleanHTML(_ raw: String) -> String {
    var output = ""
    var insideTag = false
    for character in raw {
        if character == "<" {
            insideTag = true
            continue
        }
        if character == ">" {
            insideTag = false
            continue
        }
        if !insideTag {
            output.append(character)
        }
    }
    return output
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&apos;", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func directDateString(daysBefore: Int, clock: any PublicAPIClock) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = clock.timeZone
    let date = calendar.date(byAdding: .day, value: -daysBefore, to: clock.now) ?? clock.now
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = clock.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    return formatter.string(from: date)
}

private func directKMABaseDateTime(clock: any PublicAPIClock) -> (date: String, time: String) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = clock.timeZone
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: clock.now)
    if (components.minute ?? 0) < 45 {
        let previousHour = calendar.date(byAdding: .hour, value: -1, to: clock.now) ?? clock.now
        components = calendar.dateComponents([.year, .month, .day, .hour], from: previousHour)
    }
    let date = calendar.date(from: components) ?? clock.now
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = clock.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    return (formatter.string(from: date), String(format: "%02d00", components.hour ?? 0))
}

private func significantTokens(from query: String) -> [String] {
    let noise: Set<String> = ["dart", "공시", "최근", "이슈", "사업보고서", "분기보고서", "반기보고서", "전자공시", "출처"]
    return query
        .lowercased()
        .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.count >= 2 && !noise.contains($0) }
}
