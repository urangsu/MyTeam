import Foundation

enum ExecutionVerifier {
    static func verify(
        _ output: String,
        level: VerificationLevel,
        documentType: UniversalDocumentSkillType? = nil,
        requiredSections: [String] = []
    ) -> ResultVerificationSummary {
        switch level {
        case .none:
            return ResultVerificationSummary(passed: true, issues: [])
        case .chatAnswer:
            return ResultVerifier.verifyChatAnswer(output)
        case .markdownArtifact:
            // Use document-type-specific verification if available
            if let documentType = documentType {
                return verifyDocumentType(output, type: documentType)
            }
            // Fall back to generic verification
            return ResultVerifier.verifyMarkdownArtifact(
                content: output,
                requiredSections: requiredSections
            )
        }
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

