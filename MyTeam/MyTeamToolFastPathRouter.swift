import Foundation

struct MyTeamToolFastPathMatch: Sendable, Equatable {
    let descriptor: MyTeamToolDescriptor
    let input: MyTeamToolInput
}

enum MyTeamToolFastPathRouter {
    static func match(_ message: String) -> MyTeamToolFastPathMatch? {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let lower = normalized.lowercased()

        if isGoogleSheetsReadRequest(normalized, lower: lower) {
            return make("spreadsheet.googleSheets.read", query: normalized)
        }

        if containsAny(lower, ["오늘 일정", "오늘 회의", "일정 확인", "일정 조회", "캘린더 확인", "캘린더 일정", "calendar events"]) {
            return make("calendar.events.today", query: "오늘 일정")
        }

        if isWeatherReadRequest(normalized, lower: lower) {
            return make("weather.current", query: query(afterRemoving: ["날씨", "조회", "기상청"], from: normalized, fallback: "서울"))
        }

        if containsAny(lower, ["뉴스 검색", "뉴스 찾아", "뉴스 조회", "최신 뉴스", "news search"]) {
            return make("news.search", query: query(afterRemoving: ["뉴스", "검색", "요약", "찾아줘"], from: normalized, fallback: "경제"))
        }

        if isDARTReadRequest(normalized, lower: lower) {
            return make("dart.disclosures.search", query: query(afterRemoving: ["공시", "조회", "검색", "DART", "다트"], from: normalized, fallback: "포스코"))
        }

        if containsAny(lower, ["법령 검색", "법령 찾아", "법률 검색", "조문 조회", "조문 찾아", "law search"]) {
            return make("law.search", query: query(afterRemoving: ["법령", "법률", "조문", "검색", "찾아줘"], from: normalized, fallback: "근로기준법"))
        }

        if containsAny(lower, ["회의록", "회의 메모"]) {
            return make("document.meetingMinutes", query: normalized)
        }

        if containsAny(lower, ["문서 다듬", "문장 다듬", "다듬어", "rewrite"]) {
            return make("document.rewrite", query: normalized)
        }

        if containsAny(lower, ["엑셀 후처리", "표 정리", "스프레드시트 정리"]) {
            return make("spreadsheet.postprocess", query: normalized)
        }

        return nil
    }

    static func markdown(for state: ToolExecutionState, descriptor: MyTeamToolDescriptor) -> String {
        switch state {
        case .succeeded(let result):
            var lines = [
                "### \(result.title)",
                "",
                result.summary
            ]
            if let source = result.sourceLabel {
                lines.append("")
                lines.append("출처: \(source)")
            }
            if let body = result.body, !body.isEmpty {
                lines.append("")
                lines.append(body)
            }
            if !result.items.isEmpty {
                lines.append("")
                lines.append("#### 결과")
                for item in result.items.prefix(5) {
                    let subtitle = item.subtitle.map { " — \($0)" } ?? ""
                    lines.append("- \(item.title)\(subtitle)")
                }
            }
            return lines.joined(separator: "\n")
        case .failed(let failure):
            return """
            ### \(failure.title)

            \(failure.message)
            """
        case .needsConnection(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 연결이 필요합니다."
        case .needsAssistantConnection(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 비서 연결이 필요합니다."
        case .needsValidation(let provider):
            return "\(descriptor.displayName)을 실행하려면 \(provider.displayName) 연결 검증이 필요합니다."
        case .needsApproval(let reason), .unavailable(let reason):
            return reason
        case .running, .checkingReadiness, .idle:
            return "\(descriptor.displayName) 실행 상태를 확인 중입니다."
        }
    }

    static func runningMarkdown(for descriptor: MyTeamToolDescriptor) -> String {
        """
        ### 업무 실행 중: \(descriptor.displayName)

        입력값을 확인하고 결과를 가져오는 중입니다.
        """
    }

    private static func make(_ id: String, query: String) -> MyTeamToolFastPathMatch? {
        guard let descriptor = MyTeamToolRegistry.descriptor(id: id), descriptor.isUserFacing else { return nil }
        return MyTeamToolFastPathMatch(
            descriptor: descriptor,
            input: MyTeamToolInput(
                query: query,
                daysBack: id == "dart.disclosures.search" ? 30 : nil,
                displayCount: id == "news.search" ? 5 : nil,
                providerHint: descriptor.requiredCredential?.provider
            )
        )
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func isGoogleSheetsReadRequest(_ message: String, lower: String) -> Bool {
        if lower.contains("docs.google.com/spreadsheets") { return true }
        if lower.contains("google sheets") && containsAny(lower, ["읽", "조회", "확인", "가져", "read"]) { return true }
        if containsAny(lower, ["구글시트", "구글 시트"]) && containsAny(lower, ["읽", "조회", "확인", "가져"]) { return true }
        if lower.contains("스프레드시트") && containsAny(lower, ["url", "id", "읽", "조회", "확인", "가져"]) {
            return true
        }
        return message.range(
            of: #"[A-Za-z0-9_-]{25,}\s+[A-Za-z0-9가-힣_ !']+![A-Z]+[0-9]+:[A-Z]+[0-9]+"#,
            options: .regularExpression
        ) != nil
    }

    private static func isWeatherReadRequest(_ message: String, lower: String) -> Bool {
        if containsAny(lower, ["날씨 조회", "날씨 알려", "날씨 확인", "현재 날씨", "기상청 조회", "weather"]) {
            return true
        }
        guard lower.contains("날씨") else { return false }
        if containsAny(lower, ["처럼", "문장", "카피", "기사", "형식"]) { return false }
        let compact = message.replacingOccurrences(of: "날씨", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !compact.isEmpty && compact.count <= 12
    }

    private static func isDARTReadRequest(_ message: String, lower: String) -> Bool {
        if containsAny(lower, ["공시 조회", "공시 검색", "최근 공시", "dart", "다트"]) {
            return true
        }
        guard lower.contains("공시") else { return false }
        if containsAny(lower, ["문장", "형식", "예시", "작성"]) { return false }
        let compact = message.replacingOccurrences(of: "공시", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !compact.isEmpty && compact.count <= 16
    }

    private static func query(afterRemoving tokens: [String], from message: String, fallback: String) -> String {
        var result = message
        for token in tokens {
            result = result.replacingOccurrences(of: token, with: "", options: [.caseInsensitive])
        }
        result = result
            .replacingOccurrences(of: "해줘", with: "")
            .replacingOccurrences(of: "알려줘", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }
}
