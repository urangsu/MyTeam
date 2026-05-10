import Foundation

enum ExecutionVerifier {
    static func verify(
        _ output: String,
        level: VerificationLevel,
        requiredSections: [String] = []
    ) -> ResultVerificationSummary {
        switch level {
        case .none:
            return ResultVerificationSummary(passed: true, issues: [])
        case .chatAnswer:
            return ResultVerifier.verifyChatAnswer(output)
        case .markdownArtifact:
            return ResultVerifier.verifyMarkdownArtifact(
                content: output,
                requiredSections: requiredSections
            )
        }
    }
}

