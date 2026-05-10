import Foundation

struct ResultVerificationIssue: Identifiable, Equatable {
    enum Severity: String, Codable {
        case warning
        case error
    }

    let id: UUID
    let severity: Severity
    let message: String
}

struct ResultVerificationSummary: Equatable {
    let passed: Bool
    let issues: [ResultVerificationIssue]
}

enum ResultVerifier {
    static func verifyMarkdownArtifact(content: String, requiredSections: [String] = []) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "Markdown artifact가 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        if trimmed.count < 30 {
            issues.append(issue(.warning, "검토 메모: Markdown 초안이 짧아서 확인이 필요합니다."))
        }

        if !trimmed.hasPrefix("#") {
            issues.append(issue(.warning, "검토 메모: 제목이 없거나 너무 일반적일 수 있습니다."))
        }

        for section in requiredSections where !content.contains(section) {
            issues.append(issue(.warning, "검토 메모: \(section) 섹션을 보강하면 더 좋습니다."))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyChatAnswer(_ text: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "응답이 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        if trimmed.count < 30 {
            issues.append(issue(.warning, "검토 메모: 응답이 짧아서 한 번 더 다듬을 수 있습니다."))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    private static func issue(_ severity: ResultVerificationIssue.Severity, _ message: String) -> ResultVerificationIssue {
        ResultVerificationIssue(id: UUID(), severity: severity, message: message)
    }

    private static func containsSensitiveKeywords(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "accesstoken",
            "refreshToken".lowercased(),
            "api key",
            "apikey",
            "client secret",
            "authorization code",
            "private key"
        ]
        return keywords.contains { lower.contains($0) }
    }
}
