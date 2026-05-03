import Foundation

// MARK: - DocumentGenerationService
// plan JSON → writer 라우팅 파사드
// writer 완료 후 DocumentPackageValidator로 생성 파일 무결성 자동 검증.

enum DocumentGenerationService {

    static func generatePPTX(planURL: URL, outputURL: URL) throws -> DocumentGenerationResult {
        let data = try Data(contentsOf: planURL)
        let plan = try JSONDecoder().decode(DeckPlan.self, from: data)
        let result = try PPTXWriter().write(plan: plan, to: outputURL)
        // 생성 직후 ZIP 구조 검증 — 실패 시 ToolError로 전파
        do {
            try DocumentPackageValidator.validatePPTX(at: outputURL, expectedSlideCount: plan.slides.count)
        } catch {
            AppLog.error("[DocService] PPTX validation 실패: \(error.localizedDescription)")
            throw error
        }
        return result
    }

    static func generateXLSX(planURL: URL, outputURL: URL) throws -> DocumentGenerationResult {
        let data = try Data(contentsOf: planURL)
        let plan = try JSONDecoder().decode(WorkbookPlan.self, from: data)
        let result = try XLSXWriter().write(plan: plan, to: outputURL)
        // 생성 직후 ZIP 구조 검증
        do {
            try DocumentPackageValidator.validateXLSX(at: outputURL, expectedSheetCount: plan.sheets.count)
        } catch {
            AppLog.error("[DocService] XLSX validation 실패: \(error.localizedDescription)")
            throw error
        }
        return result
    }
}
