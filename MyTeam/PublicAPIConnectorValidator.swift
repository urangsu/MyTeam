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
        components.path = "/api/list.json"
        components.queryItems = [
            URLQueryItem(name: "crtfc_key", value: apiKey),
            URLQueryItem(name: "bgn_de", value: yyyymmdd(daysBefore: 1, clock: clock)),
            URLQueryItem(name: "page_no", value: "1"),
            URLQueryItem(name: "page_count", value: "1")
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
}

struct DARTDisclosureDirectItem: Sendable, Equatable {
    let corporationName: String
    let reportName: String
    let receiptNumber: String
    let receiptDate: String
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

enum DARTDisclosureDirectConnector {
    static func recentDisclosures(
        query: String,
        apiKey: String,
        daysBack: Int = 30,
        session: URLSession = .shared,
        clock: any PublicAPIClock = SystemPublicAPIClock()
    ) async throws -> [DARTDisclosureDirectItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "opendart.fss.or.kr"
        components.path = "/api/list.json"
        components.queryItems = [
            URLQueryItem(name: "crtfc_key", value: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "bgn_de", value: directDateString(daysBefore: max(daysBack, 1), clock: clock)),
            URLQueryItem(name: "end_de", value: directDateString(daysBefore: 0, clock: clock)),
            URLQueryItem(name: "page_count", value: "20")
        ]
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }

        let (data, response) = try await session.data(for: URLRequest(url: url))
        try validateDirectHTTP(response)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectorFailureCode.responseParseFailed
        }
        let status = object["status"] as? String
        guard status == "000" else {
            if status == "013" { return [] }
            throw ConnectorFailureCode.responseParseFailed
        }
        guard let list = object["list"] as? [[String: Any]] else { return [] }
        let parsed = list.compactMap(parseItem)
        let queryTokens = significantTokens(from: trimmedQuery)
        guard !queryTokens.isEmpty else { return Array(parsed.prefix(5)) }
        let filtered = parsed.filter {
            let haystack = "\($0.corporationName) \($0.reportName)".lowercased()
            return queryTokens.contains { haystack.contains($0) }
        }
        return Array(filtered.prefix(5))
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
            reportName: reportName,
            receiptNumber: receiptNumber,
            receiptDate: receiptDate,
            sourceURL: sourceURL
        )
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

private func cleanHTML(_ raw: String) -> String {
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
