import Foundation

protocol PublicAPIClock: Sendable {
    var now: Date { get }
    var timeZone: TimeZone { get }
}

struct SystemPublicAPIClock: PublicAPIClock {
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
