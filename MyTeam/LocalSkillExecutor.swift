import Foundation

enum LocalSkillExecutionResult {
    case handled(message: String, skillID: String)
    case needsInput(message: String, skillID: String)
    case notHandled
}

enum LocalSkillExecutor {

    static func detectIfPossible(skills: [SkillManifest], userMessage: String) -> LocalSkillExecutionResult {
        if skills.contains(where: { $0.id == "korean.character-count" }) {
            if KoreanTextMetricsService.extractTargetText(from: userMessage) != nil {
                return .handled(message: "", skillID: "korean.character-count")
            }

            return .needsInput(
                message: "계산할 텍스트를 함께 보내주세요. 예: 글자 수 세줘: 안녕하세요",
                skillID: "korean.character-count"
            )
        }

        // Office review lite detection: check if skill is 1차 (immediately executable)
        for skill in skills {
            if let officeSkill = detectOfficeReviewLiteSkill(skillID: skill.id, message: userMessage) {
                if is1PhaseSkill(officeSkill) {
                    return .handled(message: "", skillID: skill.id)
                }
            }
        }

        return .notHandled
    }

    static func executeIfPossible(skills: [SkillManifest], userMessage: String) -> LocalSkillExecutionResult {
        let detection = detectIfPossible(skills: skills, userMessage: userMessage)
        switch detection {
        case .handled(_, let skillID):
            // Korean character count
            if skillID == "korean.character-count" {
                guard let targetText = KoreanTextMetricsService.extractTargetText(from: userMessage) else {
                    return detection
                }
                let metrics = KoreanTextMetricsService.analyze(targetText)
                let result = KoreanTextMetricsService.formatResult(metrics)
                return .handled(message: result, skillID: skillID)
            }

            // Office review lite execution (Round 248A)
            if let officeSkill = detectOfficeReviewLiteSkill(skillID: skillID, message: userMessage) {
                if is1PhaseSkill(officeSkill) {
                    let outcome = OfficeReviewLiteExecutor.execute(
                        skill: officeSkill,
                        text: userMessage,
                        sourceName: "user input"
                    )
                    switch outcome {
                    case .success:
                        // Execute locally, result will be passed to artifact handler
                        return .handled(message: "", skillID: skillID)
                    case .unsupported(let msg):
                        return .needsInput(message: msg, skillID: skillID)
                    case .needsAssistant(let msg):
                        return .needsInput(message: msg, skillID: skillID)
                    }
                }
            }

            return detection
        case .needsInput, .notHandled:
            return detection
        }
    }

    // MARK: - Office Review Lite Helpers

    private static func detectOfficeReviewLiteSkill(
        skillID: String,
        message: String
    ) -> OfficeReviewInputPolicy.OfficeReviewSkill? {
        switch skillID {
        case "office-review.meeting-action-items": return .meetingActionItems
        case "office-review.filename-organization": return .filenameOrganization
        case "office-review.report-tone-polish": return .reportTonePolish
        case "office-review.accounting-consistency": return .accountingConsistency
        case "office-review.vendor-name-mismatch": return .vendorNameMismatch
        case "office-review.budget-actual-analysis": return .budgetActualAnalysis
        case "office-review.invoice-description-anomaly": return .invoiceDescriptionAnomaly
        case "office-review.tax-invoice-comparison": return .taxInvoiceComparison
        case "office-review.contract-checklist": return .contractChecklist
        default: return nil
        }
    }

    private static func is1PhaseSkill(_ skill: OfficeReviewInputPolicy.OfficeReviewSkill) -> Bool {
        switch skill {
        case .meetingActionItems, .filenameOrganization, .reportTonePolish:
            return true
        default:
            return false
        }
    }
}
