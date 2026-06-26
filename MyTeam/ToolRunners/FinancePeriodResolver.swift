import Foundation

enum FinancePeriodMode: Sendable, Equatable {
    case explicit(year: String, quarter: String?)
    case latestAvailable(candidateYears: [String], candidateQuarters: [FinanceQuarterCandidate])
}

struct FinanceQuarterCandidate: Sendable, Equatable {
    let year: String
    let quarter: String
    let label: String
}

struct ResolvedFinancePeriod: Sendable, Equatable {
    let mode: FinancePeriodMode
    let userFacingLabel: String
    let isInferred: Bool
}

enum FinancePeriodResolver {
    nonisolated static let latestAvailableToken = "latestAvailable"

    nonisolated static func query(company: String, originalText: String) -> String {
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        if let year = explicitBusinessYear(from: originalText) {
            if let quarter = explicitQuarter(from: originalText) {
                return "\(trimmedCompany) \(year) \(quarter)"
            }
            return "\(trimmedCompany) \(year)"
        }
        return "\(trimmedCompany) \(latestAvailableToken)"
    }

    nonisolated static func periodMode(from query: String, now: Date = Date()) -> FinancePeriodMode {
        if let year = explicitBusinessYear(from: query) {
            return .explicit(year: year, quarter: explicitQuarter(from: query))
        }
        return .latestAvailable(
            candidateYears: candidateBusinessYears(now: now),
            candidateQuarters: candidateCompletedQuarters(now: now)
        )
    }

    nonisolated static func companyQuery(from query: String) -> String {
        let tokens = query.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
        let filtered = tokens.filter { token in
            token != latestAvailableToken
                && token.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) == nil
                && token.range(of: #"^Q[1-4]$"#, options: [.regularExpression, .caseInsensitive]) == nil
                && token.range(of: #"^[1-4]분기$"#, options: .regularExpression) == nil
        }
        return filtered.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func explicitBusinessYear(from text: String) -> String? {
        let pattern = #"\b(19|20)\d{2}\b"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }

    nonisolated static func explicitQuarter(from text: String) -> String? {
        if let range = text.range(of: #"Q[1-4]"#, options: [.regularExpression, .caseInsensitive]) {
            return String(text[range]).uppercased()
        }
        if let range = text.range(of: #"[1-4]분기"#, options: .regularExpression) {
            let value = String(text[range]).replacingOccurrences(of: "분기", with: "")
            return "Q\(value)"
        }
        return nil
    }

    nonisolated static func candidateBusinessYears(now: Date = Date()) -> [String] {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        return [year, year - 1, year - 2].map(String.init)
    }

    nonisolated static func candidateCompletedQuarters(now: Date = Date()) -> [FinanceQuarterCandidate] {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        var quarter = ((month - 1) / 3) + 1
        var candidateYear = year
        quarter -= 1
        if quarter == 0 {
            quarter = 4
            candidateYear -= 1
        }

        var candidates: [FinanceQuarterCandidate] = []
        for _ in 0..<2 {
            candidates.append(FinanceQuarterCandidate(
                year: String(candidateYear),
                quarter: "Q\(quarter)",
                label: "\(candidateYear)년 \(quarter)분기"
            ))
            quarter -= 1
            if quarter == 0 {
                quarter = 4
                candidateYear -= 1
            }
        }
        return candidates
    }

    nonisolated static func automaticSelectionNotice(year: String) -> String {
        "선택 방식: 명시 기간 없음 → 조회 가능한 최신 기준 기간 자동 선택. 기준 기간: \(year)년 사업연도."
    }

    nonisolated static func explicitSelectionNotice(year: String, quarter: String?) -> String {
        if let quarter {
            return "선택 방식: 사용자가 입력한 명시 기간. 기준 기간: \(year)년 \(quarter)."
        }
        return "선택 방식: 사용자가 입력한 명시 기간. 기준 기간: \(year)년 사업연도."
    }
}
