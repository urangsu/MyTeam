import Foundation

enum ExecutionVerifier {
    static func verify(
        _ output: String,
        level: VerificationLevel,
        sourceText: String? = nil,
        documentType: UniversalDocumentSkillType? = nil,
        requiredSections: [String] = []
    ) -> ResultVerificationSummary {
        let formatSummary: ResultVerificationSummary
        switch level {
        case .none:
            formatSummary = ResultVerificationSummary(passed: true, issues: [])
        case .chatAnswer:
            formatSummary = ResultVerifier.verifyChatAnswer(output)
        case .markdownArtifact:
            if let documentType = documentType {
                formatSummary = verifyDocumentType(output, type: documentType)
            } else {
                formatSummary = ResultVerifier.verifyMarkdownArtifact(
                    content: output,
                    requiredSections: requiredSections
                )
            }
        }

        guard let sourceText = sourceText?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceText.isEmpty else {
            return formatSummary
        }

        let groundingSummary = ResultVerifier.verifySourceGrounding(content: output, sourceText: sourceText)
        guard !groundingSummary.issues.isEmpty else {
            return formatSummary
        }

        return ResultVerificationSummary(
            passed: formatSummary.passed && groundingSummary.passed,
            issues: formatSummary.issues + groundingSummary.issues
        )
    }

    private static func verifyDocumentType(_ output: String, type: UniversalDocumentSkillType) -> ResultVerificationSummary {
        switch type {
        case .summary:
            return ResultVerifier.verifySummary(content: output)
        case .reportDraft:
            return ResultVerifier.verifyReportDraft(content: output)
        case .checklist:
            return ResultVerifier.verifyChecklist(content: output)
        case .tableSummary:
            return ResultVerifier.verifyTableSummary(content: output)
        case .meetingMinutes:
            return ResultVerifier.verifyMeetingMinutes(content: output)
        case .actionItems:
            return ResultVerifier.verifyActionItems(content: output)
        }
    }
}
