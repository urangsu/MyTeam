import Foundation

struct StockMoveAnalysisCard: Codable, Sendable {
    enum VerificationLevel: String, Codable, Sendable {
        case noSource
        case quoteOnly
        case partiallyGrounded
        case verifiedCandidate
        case conflictingSources
    }

    let companyName: String
    let ticker: String?
    let verificationLevel: VerificationLevel
    let quoteSourceTitle: String?
    let newsCount: Int
    let disclosureCount: Int
    let marketContextCount: Int
    let warnings: [String]
}
