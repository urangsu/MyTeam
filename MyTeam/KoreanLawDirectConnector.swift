import Foundation

struct KoreanLawSearchRequest: Sendable, Equatable {
    let query: String
    let lawName: String?
    let article: String?
}

struct KoreanLawCitationVerificationRequest: Sendable, Equatable {
    let citationText: String
    let expectedLawName: String?
    let expectedArticle: String?
    let expectedParagraph: String?
    let expectedItem: String?
    let expectedEffectiveDate: String?
}

struct KoreanLawSource: Sendable, Equatable {
    let title: String
    let url: URL
    let publisher: String
}

struct KoreanLawResult: Sendable, Equatable {
    enum Status: String, Sendable {
        case verified
        case partial
        case failed
    }

    let status: Status
    let lawName: String
    let article: String?
    let effectiveDate: String?
    let officialSourceURL: URL?
    let verificationStatus: String
    let summary: String
    let mismatchDetails: [String]
    let sources: [KoreanLawSource]
    let disclaimer: String
}

enum KoreanLawDirectConnector {
    nonisolated static let disclaimer = "법률 자문이 아닌 공식 출처 기반 법령 조사 결과입니다."

    static func makeSearchRequest(_ request: KoreanLawSearchRequest, lawOC: String) throws -> URLRequest {
        let query = request.lawName ?? request.query
        var components = baseComponents(path: "/DRF/lawSearch.do", lawOC: lawOC)
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "target", value: "law"),
            URLQueryItem(name: "type", value: "JSON"),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "display", value: "10")
        ])
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }
        return URLRequest(url: url)
    }

    static func makeArticleRequest(lawID: String, lawOC: String) throws -> URLRequest {
        var components = baseComponents(path: "/DRF/lawService.do", lawOC: lawOC)
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "target", value: "law"),
            URLQueryItem(name: "type", value: "JSON"),
            URLQueryItem(name: "ID", value: lawID)
        ])
        guard let url = components.url else { throw ConnectorFailureCode.responseParseFailed }
        return URLRequest(url: url)
    }

    static func parseSearchResponse(_ data: Data) -> [KoreanLawResult] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let search = object["LawSearch"] as? [String: Any]
        else {
            return []
        }

        let laws: [[String: Any]]
        if let array = search["law"] as? [[String: Any]] {
            laws = array
        } else if let single = search["law"] as? [String: Any] {
            laws = [single]
        } else {
            laws = []
        }

        return laws.compactMap { law in
            guard let lawName = law["법령명한글"] as? String else { return nil }
            let lawID = law["법령ID"] as? String
            let serial = law["법령일련번호"] as? String
            let sourceURL = officialURL(lawID: lawID, serial: serial)
            let source = sourceURL.map {
                KoreanLawSource(title: lawName, url: $0, publisher: "법제처 또는 국가법령정보센터")
            }
            return KoreanLawResult(
                status: .partial,
                lawName: lawName,
                article: nil,
                effectiveDate: law["시행일자"] as? String,
                officialSourceURL: sourceURL,
                verificationStatus: "partial",
                summary: "공식 법령 검색 결과입니다. 법률 자문이 아닙니다.",
                mismatchDetails: [],
                sources: source.map { [$0] } ?? [],
                disclaimer: disclaimer
            )
        }
    }

    static func verifyCitation(
        _ request: KoreanLawCitationVerificationRequest,
        against result: KoreanLawResult
    ) -> KoreanLawResult {
        var mismatches: [String] = []
        if let expected = request.expectedLawName, expected != result.lawName {
            mismatches.append("법령명 불일치: \(expected) != \(result.lawName)")
        }
        if let expected = request.expectedArticle {
            guard let article = result.article else {
                mismatches.append("조문 누락: \(expected)")
                return failedCitationResult(from: result, mismatches: mismatches)
            }
            if expected != article {
                mismatches.append("조문 불일치: \(expected) != \(article)")
            }
        }
        if let expected = request.expectedParagraph {
            mismatches.append("항 검증 미지원: \(expected)")
        }
        if let expected = request.expectedItem {
            mismatches.append("호 검증 미지원: \(expected)")
        }
        if let expected = request.expectedEffectiveDate {
            guard let effectiveDate = result.effectiveDate else {
                mismatches.append("시행일 누락: \(expected)")
                return failedCitationResult(from: result, mismatches: mismatches)
            }
            if expected != effectiveDate {
                mismatches.append("시행일 불일치: \(expected) != \(effectiveDate)")
            }
        }
        guard result.officialSourceURL != nil else {
            mismatches.append("공식 출처 URL 누락")
            return failedCitationResult(from: result, mismatches: mismatches)
        }
        let status: KoreanLawResult.Status = mismatches.isEmpty && result.officialSourceURL != nil ? .verified : .failed
        return KoreanLawResult(
            status: status,
            lawName: result.lawName,
            article: result.article,
            effectiveDate: result.effectiveDate,
            officialSourceURL: result.officialSourceURL,
            verificationStatus: status.rawValue,
            summary: result.summary,
            mismatchDetails: mismatches,
            sources: result.sources,
            disclaimer: result.disclaimer
        )
    }

    private static func failedCitationResult(from result: KoreanLawResult, mismatches: [String]) -> KoreanLawResult {
        KoreanLawResult(
            status: .failed,
            lawName: result.lawName,
            article: result.article,
            effectiveDate: result.effectiveDate,
            officialSourceURL: result.officialSourceURL,
            verificationStatus: KoreanLawResult.Status.failed.rawValue,
            summary: result.summary,
            mismatchDetails: mismatches,
            sources: result.sources,
            disclaimer: result.disclaimer
        )
    }

    private static func baseComponents(path: String, lawOC: String) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.law.go.kr"
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "OC", value: lawOC.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
        return components
    }

    private static func officialURL(lawID: String?, serial: String?) -> URL? {
        guard let identifier = lawID ?? serial else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.law.go.kr"
        components.path = "/법령"
        components.queryItems = [
            URLQueryItem(name: "id", value: identifier)
        ]
        return components.url
    }
}
