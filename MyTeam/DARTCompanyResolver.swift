import Foundation

enum DARTCompanyResolutionSource: String, Sendable, Equatable {
    case directCorpCode
    case stockCodeCache
    case companyNameCache
    case manualSeed
    case notFound
}

struct DARTCompanyResolution: Sendable, Equatable {
    let input: String
    let corpCode: String?
    let corpName: String?
    let stockCode: String?
    let resolutionSource: DARTCompanyResolutionSource

    var isResolved: Bool {
        corpCode != nil
    }

    nonisolated var displayName: String {
        if let corpName, let stockCode {
            return "\(corpName) \(stockCode)"
        }
        if let corpName {
            return corpName
        }
        if let corpCode {
            return corpCode
        }
        return input
    }
}

enum DARTCompanyResolver {
    private struct Seed: Sendable, Equatable {
        let corpCode: String
        let corpName: String
        let aliases: [String]
        let stockCode: String
    }

    nonisolated private static let seeds: [Seed] = [
        Seed(
            corpCode: "00126380",
            corpName: "삼성전자",
            aliases: ["삼성전자", "삼성전자(주)", "Samsung Electronics"],
            stockCode: "005930"
        )
    ]

    nonisolated static func resolve(input: String) -> DARTCompanyResolution {
        let trimmed = cleanedInput(input)
        guard !trimmed.isEmpty else {
            return notFound(input)
        }

        if isEightDigitCorpCode(trimmed) {
            if let seed = seeds.first(where: { $0.corpCode == trimmed }) {
                return resolution(seed: seed, input: input, source: .manualSeed)
            }
            return DARTCompanyResolution(
                input: input,
                corpCode: trimmed,
                corpName: nil,
                stockCode: nil,
                resolutionSource: .directCorpCode
            )
        }

        if isSixDigitStockCode(trimmed), let seed = seeds.first(where: { $0.stockCode == trimmed }) {
            return resolution(seed: seed, input: input, source: .stockCodeCache)
        }

        let normalized = normalizedName(trimmed)
        if let seed = seeds.first(where: { seed in
            normalizedName(seed.corpName) == normalized
                || seed.aliases.contains { normalizedName($0) == normalized }
        }) {
            return resolution(seed: seed, input: input, source: .companyNameCache)
        }

        return notFound(input)
    }

    nonisolated private static func resolution(
        seed: Seed,
        input: String,
        source: DARTCompanyResolutionSource
    ) -> DARTCompanyResolution {
        DARTCompanyResolution(
            input: input,
            corpCode: seed.corpCode,
            corpName: seed.corpName,
            stockCode: seed.stockCode,
            resolutionSource: source
        )
    }

    nonisolated private static func notFound(_ input: String) -> DARTCompanyResolution {
        DARTCompanyResolution(
            input: input,
            corpCode: nil,
            corpName: nil,
            stockCode: nil,
            resolutionSource: .notFound
        )
    }

    nonisolated private static func cleanedInput(_ input: String) -> String {
        input
            .replacingOccurrences(of: "corpCode:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "corp_code:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func isEightDigitCorpCode(_ input: String) -> Bool {
        input.range(of: #"^\d{8}$"#, options: .regularExpression) != nil
    }

    nonisolated private static func isSixDigitStockCode(_ input: String) -> Bool {
        input.range(of: #"^\d{6}$"#, options: .regularExpression) != nil
    }

    nonisolated private static func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "(주)", with: "")
            .replacingOccurrences(of: "주식회사", with: "")
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .punctuationCharacters)
    }
}
