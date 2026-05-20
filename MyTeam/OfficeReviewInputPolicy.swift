import Foundation

// MARK: - OfficeReviewInputPolicy
// Round 243A-OBSERVE: 사무 검토 입력 정책 및 지원 skill 목록.
//
// 정책:
// - 지원 입력: PDF, CSV, text/markdown, pasted table
// - 계획 입력: image, xlsx/docx/pptx (다음 라운드)
// - 외부 write 없음
// - 검토 결과는 artifact로 생성

enum OfficeReviewInputPolicy {

    // MARK: - Supported Inputs

    enum InputSupport {
        case supported     // 현재 지원
        case planned       // 다음 라운드 예정
        case notSupported  // 지원 안 함
    }

    static func inputSupport(for kind: ObservationContentKind) -> InputSupport {
        switch kind {
        case .pdf, .text, .markdown, .spreadsheet: return .supported
        case .image, .word, .presentation:          return .planned
        case .code:                                 return .supported
        case .archive, .unknown:                    return .notSupported
        }
    }

    /// 현재 지원하는 입력 타입
    static let supportedInputKinds: [ObservationContentKind] = [
        .pdf, .csv, .text, .markdown, .spreadsheet, .code
    ]

    /// 계획된 입력 타입 (다음 라운드)
    static let plannedInputKinds: [ObservationContentKind] = [
        .image, .word, .presentation
    ]

    // MARK: - Office Review Skills

    enum OfficeReviewSkill: String, CaseIterable {
        case accountingConsistency     = "office-review.accounting-consistency"
        case vendorNameMismatch        = "office-review.vendor-name-mismatch"
        case budgetActualAnalysis      = "office-review.budget-actual-analysis"
        case invoiceDescriptionAnomaly = "office-review.invoice-description-anomaly"
        case taxInvoiceComparison      = "office-review.tax-invoice-comparison"
        case contractChecklist         = "office-review.contract-checklist"
        case meetingActionItems        = "office-review.meeting-action-items"
        case filenameOrganization      = "office-review.filename-organization"
        case reportTonePolish          = "office-review.report-tone-polish"

        var displayName: String {
            switch self {
            case .accountingConsistency:     return "계정과목 정합성 검토"
            case .vendorNameMismatch:        return "거래처명 불일치 검토"
            case .budgetActualAnalysis:      return "예산/실적 차이 분석"
            case .invoiceDescriptionAnomaly: return "전표 설명 이상치 찾기"
            case .taxInvoiceComparison:      return "세금계산서/거래명세서 비교"
            case .contractChecklist:         return "계약서 체크리스트"
            case .meetingActionItems:        return "회의록 액션아이템 추출"
            case .filenameOrganization:      return "파일명 정리"
            case .reportTonePolish:          return "보고서 말투 정리"
            }
        }

        var compatibleInputKinds: [ObservationContentKind] {
            switch self {
            case .accountingConsistency, .vendorNameMismatch,
                 .budgetActualAnalysis, .invoiceDescriptionAnomaly,
                 .taxInvoiceComparison:
                return [.spreadsheet, .pdf, .text]
            case .contractChecklist:
                return [.pdf, .word, .text]
            case .meetingActionItems:
                return [.text, .markdown, .pdf]
            case .filenameOrganization:
                return [.text, .markdown]
            case .reportTonePolish:
                return [.text, .markdown, .word]
            }
        }
    }

    // MARK: - Result Card Structure

    struct ReviewResultCard {
        let skillID: String
        let summary: String         // 검토 요약
        let issues: [ReviewIssue]   // 발견 이슈
        let recommendedActions: [String]  // 권장 조치
        let nextActions: [String]   // 다음 액션
    }

    struct ReviewIssue {
        let severity: IssueSeverity
        let description: String
        let evidence: String        // 근거
    }

    enum IssueSeverity: String {
        case critical = "중요"
        case warning  = "주의"
        case info     = "참고"
    }

    // MARK: - Skill Suggestion

    /// 파일 종류 + 사용자 메시지로 적합한 skill 추천
    static func suggestSkill(for kind: ObservationContentKind, message: String) -> OfficeReviewSkill? {
        let lower = message.lowercased()
        if lower.contains("계정과목") || lower.contains("분개") { return .accountingConsistency }
        if lower.contains("거래처") || lower.contains("업체") { return .vendorNameMismatch }
        if lower.contains("예산") || lower.contains("실적") || lower.contains("차이") { return .budgetActualAnalysis }
        if lower.contains("전표") || lower.contains("이상") { return .invoiceDescriptionAnomaly }
        if lower.contains("세금계산서") || lower.contains("거래명세서") { return .taxInvoiceComparison }
        if lower.contains("계약서") || lower.contains("계약") { return .contractChecklist }
        if lower.contains("회의록") || lower.contains("액션") { return .meetingActionItems }
        if lower.contains("파일명") || lower.contains("정리") { return .filenameOrganization }
        if lower.contains("보고서") || lower.contains("말투") || lower.contains("문체") { return .reportTonePolish }
        return nil
    }
}

// CSV extension alias for ObservationContentKind
private extension ObservationContentKind {
    static let csv = ObservationContentKind.spreadsheet
}
