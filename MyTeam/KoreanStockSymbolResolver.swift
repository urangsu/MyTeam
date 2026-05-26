import Foundation

enum KoreanStockSymbolResolver {
    struct Resolution: Sendable, Equatable {
        let companyName: String
        let ticker: String
    }

    private static let aliases: [(keywords: [String], companyName: String, ticker: String)] = [
        (["삼성전자", "삼전"], "삼성전자", "005930.KS"),
        (["sk하이닉스", "하이닉스"], "SK하이닉스", "000660.KS"),
        (["현대차", "현대자동차"], "현대차", "005380.KS"),
        (["기아", "기아차"], "기아", "000270.KS"),
        (["naver", "네이버"], "NAVER", "035420.KS"),
        (["카카오"], "카카오", "035720.KS"),
        (["lg에너지솔루션", "엘지에너지솔루션"], "LG에너지솔루션", "373220.KS"),
        (["posco홀딩스", "포스코홀딩스", "포스코"], "POSCO홀딩스", "005490.KS"),
        (["현대모비스"], "현대모비스", "012330.KS"),
        (["셀트리온"], "셀트리온", "068270.KS")
    ]

    static func resolve(_ rawQuery: String) -> Resolution? {
        let lower = rawQuery.lowercased()
        if let match = aliases.first(where: { item in
            item.keywords.contains { lower.contains($0.lowercased()) }
        }) {
            return Resolution(companyName: match.companyName, ticker: match.ticker)
        }

        if let ticker = extractTicker(from: rawQuery) {
            return Resolution(companyName: ticker, ticker: ticker)
        }
        return nil
    }

    private static func extractTicker(from text: String) -> String? {
        let pattern = #"\b[0-9]{6}\.(?:KS|KQ)\b|\b[A-Z]{1,5}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange]).uppercased()
    }
}
