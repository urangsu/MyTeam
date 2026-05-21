import Foundation

// Round 248A-OFFICE-LITE: Lite office review executor supporting 1차 (meetingActionItems,
// filenameOrganization, reportTonePolish) with heuristics and 2차 assistOnly stubs.
//
// Constraints:
// - 1차 uses heuristic extraction, no real Excel/PDF parsing
// - 2차 returns unsupported with guidance
// - No evidence location tracking (marked unsupported)
// - No original file mutation
// - No fake parsing claims

enum OfficeReviewLiteExecutor {

    struct ReviewResult {
        let skillID: String
        let title: String
        let summary: String
        let issues: [ReviewIssue]
        let actionItems: [String]
        let limitations: [String]
        let suggestedNextSteps: [String]
    }

    struct ReviewIssue {
        let severity: String  // "critical", "warning", "info"
        let text: String
        let evidence: String
    }

    enum ExecutionOutcome {
        case success(ReviewResult)
        case needsAssistant(message: String)
        case unsupported(message: String)
    }

    // MARK: - Main Executor

    static func execute(
        skill: OfficeReviewInputPolicy.OfficeReviewSkill,
        text: String,
        sourceName: String
    ) -> ExecutionOutcome {
        switch skill {
        // 1차: Heuristic implementations
        case .meetingActionItems:
            return executeMeetingActionItems(text: text, sourceName: sourceName)
        case .filenameOrganization:
            return executeFilenameOrganization(text: text, sourceName: sourceName)
        case .reportTonePolish:
            return executeReportTonePolish(text: text, sourceName: sourceName)

        // 2차: Assistant-only stubs
        case .accountingConsistency:
            return .unsupported(message: "계정과목 정합성 검토는 전문 회계 검토가 필요합니다. LLM 기반 상담을 원하시면 '계정과목 검토 도와줘'라고 말씀해 주세요.")
        case .vendorNameMismatch:
            return .unsupported(message: "거래처명 불일치 검토는 상세한 거래처 관리 데이터 비교가 필요합니다. LLM 상담을 원하시면 '거래처명 검토 도와줘'라고 말씀해 주세요.")
        case .budgetActualAnalysis:
            return .unsupported(message: "예산/실적 차이 분석은 수치 기반 정밀 분석이 필요합니다. LLM 상담을 원하시면 '예산 분석 도와줘'라고 말씀해 주세요.")
        case .invoiceDescriptionAnomaly:
            return .unsupported(message: "전표 설명 이상치 찾기는 거래 문맥 이해가 필요합니다. LLM 상담을 원하시면 '전표 검토 도와줘'라고 말씀해 주세요.")
        case .taxInvoiceComparison:
            return .unsupported(message: "세금계산서 비교는 세무 규정 검토가 필요합니다. LLM 상담을 원하시면 '세금계산서 비교 도와줘'라고 말씀해 주세요.")
        case .contractChecklist:
            return .unsupported(message: "계약서 체크리스트는 법률 검토가 필요합니다. LLM 상담을 원하시면 '계약서 검토 도와줘'라고 말씀해 주세요.")
        }
    }

    // MARK: - 1차 Heuristic Implementations

    private static func executeMeetingActionItems(text: String, sourceName: String) -> ExecutionOutcome {
        let actionItems = extractActionItems(from: text)
        let hasContent = !actionItems.isEmpty

        let result = ReviewResult(
            skillID: "office-review.meeting-action-items",
            title: "회의록 액션아이템",
            summary: hasContent
                ? "총 \(actionItems.count)개의 액션아이템을 추출했습니다."
                : "텍스트에서 액션아이템을 추출할 수 없었습니다.",
            issues: [],
            actionItems: actionItems,
            limitations: [
                "휴리스틱 기반 추출: 키워드(확인·준비·검토 등)로 후보를 식별합니다.",
                "근거 위치 추적 미지원: 원문에서 정확한 위치를 표시하지 않습니다.",
                "복합 문장 분석 한계: 여러 액션이 한 문장에 있으면 일부 누락될 수 있습니다."
            ],
            suggestedNextSteps: [
                "추출된 액션아이템을 검토하고 필요시 수정해 주세요.",
                "담당자와 기한을 명시해 추적 템플릿을 작성하시길 권장합니다."
            ]
        )
        return .success(result)
    }

    private static func executeFilenameOrganization(text: String, sourceName: String) -> ExecutionOutcome {
        let suggestions = suggestFilenamingPatterns(from: text)

        let result = ReviewResult(
            skillID: "office-review.filename-organization",
            title: "파일명 정리",
            summary: suggestions.isEmpty
                ? "파일명 정리를 위한 충분한 정보를 추출할 수 없었습니다."
                : "파일명 정리를 위한 \(suggestions.count)가지 패턴을 제안합니다.",
            issues: [],
            actionItems: suggestions,
            limitations: [
                "휴리스틱 기반 제안: 텍스트의 주제, 날짜, 버전 정보를 기반으로 패턴을 제안합니다.",
                "컨텍스트 의존성: 조직의 파일명 규칙에 따라 조정이 필요할 수 있습니다.",
                "실제 파일 생성 미지원: 제안만 제공하며 파일명 변경은 직접 수행해야 합니다."
            ],
            suggestedNextSteps: [
                "제안된 패턴을 조직의 네이밍 가이드라인과 비교해 주세요.",
                "선택한 패턴으로 파일명을 수정하고 필요시 폴더 구조도 정리하세요."
            ]
        )
        return .success(result)
    }

    private static func executeReportTonePolish(text: String, sourceName: String) -> ExecutionOutcome {
        let issues = detectToneIssues(from: text)

        let result = ReviewResult(
            skillID: "office-review.report-tone-polish",
            title: "보고서 말투 정리",
            summary: issues.isEmpty
                ? "특별한 말투 개선점을 발견하지 못했습니다."
                : "\(issues.count)개의 말투 개선 제안이 있습니다.",
            issues: issues,
            actionItems: [],
            limitations: [
                "휴리스틱 기반 분석: 문체 경직, 피동형, 과도한 경어 등을 감지합니다.",
                "LLM 재작성 미지원: 개선 제안만 제공하며 직접 문장 수정은 제공하지 않습니다.",
                "원문 변경 미지원: 검토 결과만 제공하며 원문 파일을 수정하지 않습니다."
            ],
            suggestedNextSteps: [
                "제안된 개선점을 검토하고 필요한 문장을 수정해 주세요.",
                "조직의 리포팅 스타일 가이드라인이 있다면 참고하세요."
            ]
        )
        return .success(result)
    }

    // MARK: - Heuristic Extraction Helpers

    private static func extractActionItems(from text: String) -> [String] {
        let lines = text.split(separator: "\n").map(String.init)
        var items: [String] = []

        let actionKeywords = ["확인", "준비", "검토", "제출", "완료", "연락", "조율", "요청", "작성", "보완"]
        let assignmentPatterns = ["담당:", "예정:", "기한:", "기일:"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Skip headers and separators
            if trimmed.contains("-") && trimmed.count < 10 { continue }

            for keyword in actionKeywords {
                if trimmed.contains(keyword) {
                    // Check if line looks like an action (has some substance)
                    if trimmed.count > 5 {
                        items.append(trimmed)
                    }
                    break
                }
            }

            for pattern in assignmentPatterns {
                if trimmed.contains(pattern) {
                    items.append(trimmed)
                    break
                }
            }
        }

        // Deduplicate and limit to reasonable number
        let unique = Array(Set(items))
        return unique.prefix(20).sorted()
    }

    private static func suggestFilenamingPatterns(from text: String) -> [String] {
        var suggestions: [String] = []

        // Extract potential date
        let datePattern = try! NSRegularExpression(pattern: "\\d{4}년\\s?\\d{1,2}월|\\d{4}-\\d{2}(-\\d{2})?", options: [])
        let dateMatches = datePattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        let dates = dateMatches.compactMap { Range($0.range, in: text).map(String.init) }
        if !dates.isEmpty {
            suggestions.append("[DATE]_[TOPIC]_[VERSION].xlsx    (예: 20260521_매출현황_v1.xlsx)")
        }

        // Extract potential topic (first meaningful words)
        if !text.split(separator: " ").isEmpty {
            suggestions.append("[CATEGORY]_[DATE]_[TOPIC].xlsx    (예: 재무_20260521_월간실적.xlsx)")
        }

        // Standard pattern suggestions
        suggestions.append("[PROJECT]_[TYPE]_[DATE]_[VERSION].xlsx")
        suggestions.append("[DEPARTMENT]_[DOCUMENT]_[FISCAL_MONTH]_FINAL.xlsx")

        return Array(suggestions.prefix(3))
    }

    private static func detectToneIssues(from text: String) -> [ReviewIssue] {
        var issues: [ReviewIssue] = []

        let lines = text.split(separator: "\n").map(String.init)
        var lineNum = 0

        for line in lines {
            lineNum += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Passive voice detection
            if trimmed.contains("되었습니다") || trimmed.contains("되고 있습니다") {
                issues.append(ReviewIssue(
                    severity: "info",
                    text: "피동형 표현을 능동형으로 변경하면 더 명확합니다.",
                    evidence: "line \(lineNum): \(trimmed.prefix(40))..."
                ))
            }

            // Excessive polite endings
            if trimmed.contains("하겠습니다") && trimmed.count < 20 {
                issues.append(ReviewIssue(
                    severity: "info",
                    text: "짧은 문장에서 과도한 경어는 형식적으로 보일 수 있습니다.",
                    evidence: "line \(lineNum): \(trimmed.prefix(40))..."
                ))
            }

            // Wordy phrases
            if trimmed.contains("다양한 관점에서") || trimmed.contains("종합적으로 검토한 결과") {
                issues.append(ReviewIssue(
                    severity: "info",
                    text: "길게 표현된 구를 더 간결하게 쓸 수 있습니다.",
                    evidence: "line \(lineNum)"
                ))
            }
        }

        return Array(issues.prefix(5))
    }

    // MARK: - Markdown Formatter (Round 248A-HOTFIX)

    static func formatMarkdown(_ result: ReviewResult) -> String {
        var lines: [String] = []

        lines.append("## \(result.title)")
        lines.append("")
        lines.append(result.summary)

        if !result.actionItems.isEmpty {
            lines.append("")
            lines.append("### 추천 조치")
            for item in result.actionItems {
                lines.append("- \(item)")
            }
        }

        if !result.issues.isEmpty {
            lines.append("")
            lines.append("### 발견 사항")
            for issue in result.issues {
                let badge = issue.severity == "critical" ? "🔴" : issue.severity == "warning" ? "🟡" : "🔵"
                lines.append("\(badge) \(issue.text)")
                if !issue.evidence.isEmpty {
                    lines.append("  휴리스틱 참고: \(issue.evidence)")
                }
            }
        }

        // Limitations are mandatory (always shown)
        lines.append("")
        lines.append("### 한계 안내")
        for limitation in result.limitations {
            lines.append("- \(limitation)")
        }
        lines.append("- 원본 파일은 수정하지 않았습니다.")
        lines.append("- 근거 위치 추적은 아직 지원하지 않습니다.")

        if !result.suggestedNextSteps.isEmpty {
            lines.append("")
            lines.append("### 다음 단계")
            for (idx, step) in result.suggestedNextSteps.enumerated() {
                lines.append("\(idx + 1). \(step)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
