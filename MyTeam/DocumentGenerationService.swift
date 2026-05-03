import Foundation

// MARK: - DocumentGenerationService
// plan JSON → writer 라우팅 파사드

enum DocumentGenerationService {

    static func generatePPTX(planURL: URL, outputURL: URL) throws -> DocumentGenerationResult {
        let data = try Data(contentsOf: planURL)
        let plan = try JSONDecoder().decode(DeckPlan.self, from: data)
        return try PPTXWriter().write(plan: plan, to: outputURL)
    }

    static func generateXLSX(planURL: URL, outputURL: URL) throws -> DocumentGenerationResult {
        let data = try Data(contentsOf: planURL)
        let plan = try JSONDecoder().decode(WorkbookPlan.self, from: data)
        return try XLSXWriter().write(plan: plan, to: outputURL)
    }
}
