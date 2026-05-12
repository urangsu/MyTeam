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

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var hasError: Bool {
        errorCount > 0
    }
}

enum ResultVerifier {
    // MARK: - Document-Type-Specific Verification

    static func verifySummary(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "문서 요약이 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 최소 200자 요구
        if trimmed.count < 200 {
            issues.append(issue(.error, "문서 요약은 최소 200자 이상이어야 합니다. 현재: \(trimmed.count)자"))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyReportDraft(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "보고서 초안이 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 필수 섹션 중 최소 2개 이상 검사 (목적, 배경, 현황, 검토 의견)
        let requiredSections = ["목적", "배경", "현황", "검토 의견"]
        let foundSections = requiredSections.filter { content.contains($0) }.count
        if foundSections < 2 {
            issues.append(issue(.error, "보고서 초안에 필수 섹션이 부족합니다. 필수 섹션(목적, 배경, 현황, 검토 의견) 중 최소 2개 이상 필요합니다. 현재: \(foundSections)개"))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyChecklist(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "체크리스트가 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 최소 3개 항목 검사 (마크다운 리스트 아이템)
        let checklistItems = trimmed.components(separatedBy: "\n").filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("* ") }
        if checklistItems.count < 3 {
            issues.append(issue(.error, "체크리스트는 최소 3개 이상의 항목이 필요합니다. 현재: \(checklistItems.count)개"))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyTableSummary(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "표 정리가 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 마크다운 테이블 또는 key-value 구조 검사
        let hasMarkdownTable = trimmed.contains("|") && trimmed.contains("---")
        let hasKeyValue = trimmed.components(separatedBy: "\n").filter { $0.contains(":") }.count >= 2
        if !hasMarkdownTable && !hasKeyValue {
            issues.append(issue(.error, "표 정리는 마크다운 테이블 또는 key-value 구조를 포함해야 합니다."))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyMeetingMinutes(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "회의록이 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 필수 섹션 중 최소 2개 이상 검사 (회의 목적, 논의사항, 결정사항, 액션아이템)
        let requiredSections = ["회의 목적", "논의사항", "결정사항", "액션아이템"]
        let foundSections = requiredSections.filter { content.contains($0) }.count
        if foundSections < 2 {
            issues.append(issue(.error, "회의록에 필수 섹션이 부족합니다. 필수 섹션(회의 목적, 논의사항, 결정사항, 액션아이템) 중 최소 2개 이상 필요합니다. 현재: \(foundSections)개"))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifyActionItems(content: String) -> ResultVerificationSummary {
        var issues: [ResultVerificationIssue] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            issues.append(issue(.error, "액션아이템이 비어 있습니다."))
            return ResultVerificationSummary(passed: false, issues: issues)
        }

        // 최소 2개 항목 또는 담당/할일/기한 정보 검사
        let actionItems = trimmed.components(separatedBy: "\n").filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("* ") }
        let hasResponsibility = trimmed.contains("담당") || trimmed.contains("담당자")
        let hasDeadline = trimmed.contains("기한") || trimmed.contains("마감")
        let hasTask = trimmed.contains("할일") || trimmed.contains("할 일")

        if actionItems.count < 2 && !(hasResponsibility && hasDeadline && hasTask) {
            issues.append(issue(.error, "액션아이템은 최소 2개 이상의 항목 또는 담당/할일/기한 정보를 포함해야 합니다. 현재 항목: \(actionItems.count)개"))
        }

        if containsSensitiveKeywords(trimmed) {
            issues.append(issue(.error, "민감한 토큰 또는 키워드가 포함되어 있습니다."))
        }

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    // MARK: - Generic Verification (Backwards Compatibility)

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

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 업무용으로 보입니다."))
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

        if containsPersonaTone(trimmed) {
            issues.append(issue(.warning, "검토 메모: 캐릭터 말투나 1인칭 표현을 줄이면 더 깔끔합니다."))
        }

        return ResultVerificationSummary(
            passed: !issues.contains(where: { $0.severity == .error }),
            issues: issues
        )
    }

    static func verifySourceGrounding(
        content: String,
        sourceText: String
    ) -> ResultVerificationSummary {
        let sourceTokens = groundingTokens(in: sourceText)
        guard !sourceTokens.isEmpty else {
            return ResultVerificationSummary(passed: true, issues: [])
        }

        let outputTokens = groundingTokens(in: content)
        let extraTokens = outputTokens.subtracting(sourceTokens)

        guard !extraTokens.isEmpty else {
            return ResultVerificationSummary(passed: true, issues: [])
        }

        let limited = Array(extraTokens.sorted().prefix(5)).joined(separator: ", ")
        return ResultVerificationSummary(
            passed: false,
            issues: [
                issue(.error, "원문에 없는 숫자 또는 날짜가 포함되어 있습니다: \(limited)")
            ]
        )
    }

    private static func groundingTokens(in text: String) -> Set<String> {
        let normalized = text
            .split(separator: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("-"), !trimmed.hasPrefix("*"), !trimmed.hasPrefix(">") else {
                    return false
                }
                return trimmed.range(of: #"^\d+[.)]\s"#, options: .regularExpression) == nil
            }
            .joined(separator: "\n")

        let numberPattern = #"(?<![A-Za-z0-9])\d+(?:[.,]\d+)?(?![A-Za-z0-9])"#
        let datePattern = #"\b\d{4}[./-]\d{1,2}[./-]\d{1,2}\b|\b\d{1,2}월\s*\d{1,2}일\b"#

        return Set(matches(of: numberPattern, in: normalized))
            .union(matches(of: datePattern, in: normalized))
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
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

    private static func containsPersonaTone(_ text: String) -> Bool {
        let keywords = [
            "캐릭터",
            "제가 해볼게요",
            "제가 도와",
            "해볼게요",
            "팀원",
            "레오가",
            "루나가",
            "모코가"
        ]
        return keywords.contains { text.contains($0) }
    }
}
