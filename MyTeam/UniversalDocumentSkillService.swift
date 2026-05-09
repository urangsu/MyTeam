import Foundation

enum UniversalDocumentSkillService {
    static func detectSkillType(from message: String) -> UniversalDocumentSkillType? {
        let lower = message.lowercased()

        if containsAny(lower, keywords: universalDocumentKeywords(for: .meetingMinutes)) { return .meetingMinutes }
        if containsAny(lower, keywords: universalDocumentKeywords(for: .actionItems)) { return .actionItems }
        if containsAny(lower, keywords: universalDocumentKeywords(for: .checklist)) { return .checklist }
        if containsAny(lower, keywords: universalDocumentKeywords(for: .tableSummary)) { return .tableSummary }
        if containsAny(lower, keywords: universalDocumentKeywords(for: .reportDraft)) { return .reportDraft }
        if containsAny(lower, keywords: universalDocumentKeywords(for: .summary)) { return .summary }
        return nil
    }

    static func extractRequest(from message: String, type: UniversalDocumentSkillType) -> UniversalDocumentSkillRequest {
        let title = extractTitle(from: message, type: type)
        let sourceText = extractSourceText(from: message)
        return UniversalDocumentSkillRequest(
            type: type,
            title: title,
            topic: title,
            sourceText: sourceText,
            userMessage: message
        )
    }

    static func needsMoreInput(_ request: UniversalDocumentSkillRequest) -> Bool {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = request.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !source.isEmpty { return false }
        return title.isEmpty || title == "문서" || title == request.type.promptTitleSuffix
    }

    static func missingInputMessage(for request: UniversalDocumentSkillRequest) -> String {
        """
        \(request.type.displayName)를 만들려면 원문이나 주제가 조금 더 있으면 좋습니다.
        지금 문맥만으로도 작성 가정은 가능하지만, 텍스트를 함께 주시면 더 정확하게 정리할 수 있습니다.
        """
    }

    static func buildPrompt(for request: UniversalDocumentSkillRequest) -> String {
        let sections = requiredSections(for: request.type).map { "## \($0)" }.joined(separator: "\n")
        let sourceText = sourceText(from: request)
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? request.type.promptTitleSuffix : request.title

        return """
        당신은 MyTeam의 범용 문서 워크플로우입니다.
        한국어 업무 문서체로, 실제 실무자가 바로 수정할 수 있는 Markdown 초안을 작성하세요.
        과장된 문구보다 명확한 내용과 바로 복사 가능한 문장을 우선하세요.
        부족한 정보는 반드시 "작성 가정" 섹션에 명시하세요.
        법적/의학적/세무 판단은 단정하지 말고 검토용 초안으로만 작성하세요.
        문서는 제목과 소제목, 불릿 중심으로 구성하세요.
        마지막에는 반드시 "다음 수정 포인트"를 포함하세요.

        작성할 문서 유형: \(request.type.displayName)
        문서 제목: \(title)
        주제: \(request.topic)

        사용자 요청:
        \(request.userMessage)

        원문 또는 참고 텍스트:
        \(sourceText)

        출력 형식:
        # \(title) \(request.type.promptTitleSuffix)
        \(sections)

        각 섹션은 바로 편집 가능한 문장으로 채우세요.
        """
    }

    static func requiredSections(for type: UniversalDocumentSkillType) -> [String] {
        switch type {
        case .summary:
            return ["0. 작성 가정", "1. 핵심 요약", "2. 주요 내용", "3. 중요한 조건", "4. 리스크 또는 주의사항", "5. 다음 액션", "6. 다음 수정 포인트"]
        case .reportDraft:
            return ["0. 작성 가정", "1. 목적", "2. 배경", "3. 현황", "4. 주요 이슈", "5. 검토 의견", "6. 제안", "7. 다음 액션", "8. 다음 수정 포인트"]
        case .checklist:
            return ["0. 작성 가정", "1. 사전 준비", "2. 진행 중 확인사항", "3. 완료 전 점검", "4. 리스크 체크", "5. 우선순위 높은 TODO", "6. 다음 수정 포인트"]
        case .tableSummary:
            return ["0. 작성 가정", "1. 요약 표", "2. 항목별 설명", "3. 빠진 정보", "4. 다음 액션", "5. 다음 수정 포인트"]
        case .meetingMinutes:
            return ["0. 작성 가정", "1. 회의 목적", "2. 논의사항", "3. 결정사항", "4. 액션아이템", "5. 후속 확인사항", "6. 다음 수정 포인트"]
        case .actionItems:
            return ["0. 작성 가정", "1. 바로 할 일", "2. 이번 주 할 일", "3. 확인이 필요한 일", "4. 담당자/기한 정리", "5. 다음 확인 질문", "6. 다음 수정 포인트"]
        }
    }

    static func outputFilename(for request: UniversalDocumentSkillRequest) -> String {
        let datePrefix = fileDateFormatter.string(from: Date())
        let rawBase = request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? request.topic : request.title
        let base = sanitized(rawBase)
        return "\(datePrefix)_\(base.isEmpty ? request.type.filenameSuffix : base)_\(request.type.filenameSuffix).md"
    }

    static func documentTitle(for request: UniversalDocumentSkillRequest) -> String {
        let subject = request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? request.type.promptTitleSuffix : request.title
        return "\(subject) \(request.type.promptTitleSuffix)"
    }

    static func documentBody(for request: UniversalDocumentSkillRequest) -> String {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? request.type.promptTitleSuffix : request.title
        var lines: [String] = []
        lines.append("# \(title) \(request.type.promptTitleSuffix)")
        lines.append("")
        lines.append("## 0. 작성 가정")
        lines.append("")
        lines.append(contentsOf: assumptionBullets(for: request).map { "- \($0)" })
        lines.append("")
        lines.append(typeSpecificBody(for: request))
        lines.append("")
        lines.append("## 다음 수정 포인트")
        lines.append("")
        lines.append("- 실제 업무 맥락에 맞게 용어를 통일하세요.")
        lines.append("- 빠진 숫자/기한/담당자는 수동으로 보완하세요.")
        lines.append("- 확인되지 않은 정보는 검토 후 반영하세요.")
        if let sourceText = request.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceText.isEmpty {
            lines.append("")
            lines.append("## 참고 원문")
            lines.append("")
            lines.append(sourceText)
        }
        return lines.joined(separator: "\n")
    }

    private static func typeSpecificBody(for request: UniversalDocumentSkillRequest) -> String {
        switch request.type {
        case .summary:
            return """
            ## 1. 핵심 요약
            - 요청 내용을 한 문단으로 요약합니다.
            - 중요한 결론을 먼저 제시합니다.

            ## 2. 주요 내용
            - 세부 항목을 불릿으로 정리합니다.

            ## 3. 중요한 조건
            - 원문에서 유지해야 할 조건을 적습니다.

            ## 4. 리스크 또는 주의사항
            - 빠지면 안 되는 포인트를 적습니다.

            ## 5. 다음 액션
            - 다음 단계에서 바로 할 일을 적습니다.
            """
        case .reportDraft:
            return """
            ## 1. 목적
            - 이 문서의 목적을 한 줄로 정리합니다.

            ## 2. 배경
            - 왜 이 문서가 필요한지 정리합니다.

            ## 3. 현황
            - 현재 상황을 객관적으로 정리합니다.

            ## 4. 주요 이슈
            - 핵심 쟁점을 불릿으로 정리합니다.

            ## 5. 검토 의견
            - 판단 근거와 방향을 적습니다.

            ## 6. 제안
            - 실행 제안을 간결하게 적습니다.

            ## 7. 다음 액션
            - 바로 수행할 후속 작업을 적습니다.
            """
        case .checklist:
            return """
            ## 1. 사전 준비
            - 시작 전에 확인할 항목을 적습니다.

            ## 2. 진행 중 확인사항
            - 작업 중 확인할 항목을 적습니다.

            ## 3. 완료 전 점검
            - 마무리 전에 확인할 항목을 적습니다.

            ## 4. 리스크 체크
            - 실패 가능성이나 주의사항을 적습니다.

            ## 5. 우선순위 높은 TODO
            - 지금 바로 처리할 일을 적습니다.
            """
        case .tableSummary:
            return """
            ## 1. 요약 표

            | 항목 | 내용 | 우선순위 | 비고 |
            |---|---|---:|---|

            ## 2. 항목별 설명
            - 표에서 중요한 항목을 풀어서 설명합니다.

            ## 3. 빠진 정보
            - 추가로 채워야 할 정보를 적습니다.

            ## 4. 다음 액션
            - 다음에 할 일을 적습니다.
            """
        case .meetingMinutes:
            return """
            ## 1. 회의 목적
            - 회의의 목적을 적습니다.

            ## 2. 논의사항
            - 주요 논의 내용을 요약합니다.

            ## 3. 결정사항
            - 합의된 내용을 적습니다.

            ## 4. 액션아이템

            | 담당 | 할 일 | 기한 | 상태 |
            |---|---|---|---|

            ## 5. 후속 확인사항
            - 회의 후 확인할 항목을 적습니다.
            """
        case .actionItems:
            return """
            ## 1. 바로 할 일
            - 즉시 시작할 일을 적습니다.

            ## 2. 이번 주 할 일
            - 이번 주 안에 처리할 일을 적습니다.

            ## 3. 확인이 필요한 일
            - 결정 전에 확인해야 할 일을 적습니다.

            ## 4. 담당자/기한 정리

            | 할 일 | 담당 | 기한 | 우선순위 |
            |---|---|---|---:|

            ## 5. 다음 확인 질문
            - 답이 필요한 질문을 적습니다.
            """
        }
    }

    private static func assumptionBullets(for request: UniversalDocumentSkillRequest) -> [String] {
        var bullets: [String] = [
            "요청 문맥만으로도 초안을 만들 수 있도록 작성합니다.",
            "부족한 숫자/기한/담당자는 작성 가정으로 표시합니다."
        ]
        if let sourceText = request.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceText.isEmpty {
            bullets.append("제공된 원문을 우선 반영합니다.")
        } else {
            bullets.append("원문이 없으면 요청 메시지를 기준으로 문서를 구성합니다.")
        }
        return bullets
    }

    private static func sourceText(from request: UniversalDocumentSkillRequest) -> String {
        let source = request.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (source?.isEmpty == false ? source! : "원문이 없으면 요청 문맥과 작성 가정을 기준으로 작성하세요.")
    }

    private static func extractTitle(from message: String, type: UniversalDocumentSkillType) -> String {
        var cleaned = message
        for keyword in universalDocumentKeywords(for: type) + fillerKeywords {
            cleaned = cleaned.replacingOccurrences(
                of: keyword,
                with: " ",
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil
            )
        }
        cleaned = cleaned
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(cleaned.prefix(48))
        return value.isEmpty ? "문서" : value
    }

    private static func extractSourceText(from message: String) -> String? {
        let lines = message.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard lines.count > 1 else { return nil }
        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 20 else { return nil }
        return body
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func universalDocumentKeywords(for type: UniversalDocumentSkillType) -> [String] {
        switch type {
        case .summary:
            return ["요약", "핵심 요약", "문서 요약", "정리"]
        case .reportDraft:
            return ["보고서", "검토 보고서", "보고서 초안", "리포트"]
        case .checklist:
            return ["체크리스트", "점검표", "할 일 목록"]
        case .tableSummary:
            return ["표로 정리", "표 정리", "표로", "표"]
        case .meetingMinutes:
            return ["회의록", "회의록처럼", "회의 내용", "미팅 정리"]
        case .actionItems:
            return ["액션아이템", "액션 아이템", "해야 할 일", "다음 액션", "todo"]
        }
    }

    private static let fillerKeywords = [
        "만들어줘",
        "작성해줘",
        "정리해줘",
        "뽑아줘",
        "추출해줘",
        "만들어",
        "작성해",
        "뽑아",
        "추출해",
        "처럼",
        "형태로"
    ]

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let converted = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(converted).replacingOccurrences(of: "__", with: "_")
        return String(collapsed.prefix(60)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
