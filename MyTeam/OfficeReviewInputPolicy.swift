import Foundation

// MARK: - OfficeReviewInputPolicy
// Round 243A-OBSERVE: 사무 검토 입력 정책 및 지원 skill 목록.
//
// 정책:
// - 입력 감지: PDF, CSV, text/markdown, pasted table
// - 계획 입력: image, xlsx/docx/pptx (다음 라운드)
// - 외부 write 없음
// - 검토 결과는 artifact로 생성
//
// Round 246A (P1-6): "supported" 표현 제거 → OfficeReviewExecutionStatus로 단계 명시.
// "계정과목 정합성 된다면서 왜 안 돼?" 방지.

enum OfficeReviewInputPolicy {

    // MARK: - Execution Status (Round 246A)
    // 각 스킬이 현재 어느 단계까지 구현되었는지 명시.

    enum OfficeReviewExecutionStatus {
        case policyDefined     // 정책 선언·스킬 등록만, 실행 없음
        case inputDetected     // 파일 감지 가능
        case textExtracted     // 텍스트 추출 가능
        case tableParsed       // 표 파싱 가능
        case reviewGenerated   // 검토 결과 생성 가능 (LLM 기반)
        case evidenceLinked    // 근거 위치 추적 가능
        case exportReady       // 결과물 내보내기 가능
    }

    // MARK: - Input Readiness (supported → inputReadiness로 rename)

    enum InputReadiness {
        case inputDetected   // 파일 감지·텍스트 읽기 가능 (이전 "supported")
        case planned         // 다음 라운드 예정
        case notSupported    // 지원 안 함
    }

    static func inputReadiness(for kind: ObservationContentKind) -> InputReadiness {
        switch kind {
        case .pdf, .text, .markdown, .spreadsheet: return .inputDetected
        case .image, .word, .presentation:          return .planned
        case .code:                                 return .inputDetected
        case .archive, .unknown:                    return .notSupported
        }
    }

    /// 현재 inputDetected 단계인 입력 타입
    static let detectedInputKinds: [ObservationContentKind] = [
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

        // Round 246A: 현재 구현 단계. 표 파싱·근거 추적 없으므로 대부분 policyDefined.
        var executionStatus: OfficeReviewExecutionStatus {
            switch self {
            case .meetingActionItems, .filenameOrganization, .reportTonePolish:
                // text-based → 텍스트 읽기 가능, LLM으로 결과 생성 가능
                return .reviewGenerated
            case .accountingConsistency, .vendorNameMismatch,
                 .budgetActualAnalysis, .invoiceDescriptionAnomaly,
                 .taxInvoiceComparison, .contractChecklist:
                // 표 파싱·근거 위치 추적 미구현 → inputDetected 단계
                return .inputDetected
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

    // MARK: - Round 246B: AssistOnly UX

    /// 파일 없이 office-review 요청 시 사용자에게 돌려주는 안내 메시지
    static let noFileProvidedMessage =
        "검토할 파일을 올려주세요. PDF, CSV, 텍스트, 스프레드시트 파일을 드롭하거나 텍스트를 붙여넣으시면 바로 시작할 수 있습니다."

    /// executionStatus에 따른 정직한 기능 상태 안내
    static func executionStatusMessage(for skill: OfficeReviewSkill) -> String {
        switch skill.executionStatus {
        case .policyDefined:
            return "\(skill.displayName) 기능은 정책이 정의되어 있으나 아직 실행 로직이 구현되지 않았습니다. 파일을 주시면 초안 형태로 도와드릴 수 있습니다."
        case .inputDetected:
            return "\(skill.displayName)은(는) 파일을 읽어 내용을 분석하는 기능입니다. 단, 표 파싱 및 근거 위치 추적은 아직 미구현 상태입니다. 텍스트 기반 초안 검토는 가능합니다."
        case .textExtracted:
            return "\(skill.displayName)은(는) 텍스트 추출까지 가능합니다. 세부 표 파싱·근거 링크는 준비 중입니다."
        case .tableParsed:
            return "\(skill.displayName)은(는) 표 파싱이 가능하여 수치 분석을 할 수 있습니다. 근거 위치 추적(evidenceLinked)은 준비 중입니다."
        case .reviewGenerated:
            return "\(skill.displayName) 기능을 사용할 수 있습니다. 검토할 내용을 붙여넣어 주세요."
        case .evidenceLinked:
            return "\(skill.displayName) 검토 결과에 근거 위치가 포함됩니다."
        case .exportReady:
            return "\(skill.displayName) 검토 결과를 내보낼 수 있습니다."
        }
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
