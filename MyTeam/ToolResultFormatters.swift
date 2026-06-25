import Foundation

enum LocalBriefingResultFormatter {
    nonisolated static func items(from snapshot: DailyBriefingLocalSnapshot) -> [MyTeamToolResultItem] {
        let taskItems = snapshot.taskItems.prefix(3).map { item in
            MyTeamToolResultItem(
                id: item.id.uuidString,
                title: item.title,
                subtitle: item.dueText,
                metadata: "우선순위 \(item.priority)",
                sourceURL: nil
            )
        }
        let attentionItems = snapshot.attentionItems.prefix(3).map { item in
            MyTeamToolResultItem(
                id: item.id.uuidString,
                title: item.title,
                subtitle: item.detail,
                metadata: item.severity.rawValue,
                sourceURL: nil
            )
        }
        return Array(taskItems + attentionItems).prefix(5).map { $0 }
    }

    nonisolated static func body(from snapshot: DailyBriefingLocalSnapshot) -> String {
        var lines: [String] = [
            "# 오늘 로컬 업무 브리핑",
            "",
            "## 요약",
            "- \(snapshot.summary)",
            "",
            "## 오늘 할 일"
        ]
        if snapshot.taskItems.isEmpty {
            lines.append("- 현재 로컬 작업에서 바로 표시할 할 일이 없습니다.")
        } else {
            lines.append(contentsOf: snapshot.taskItems.prefix(5).map { item in
                let due = item.dueText.map { " · \($0)" } ?? ""
                return "- \(item.title)\(due)"
            })
        }
        lines.append("")
        lines.append("## 확인 필요")
        if snapshot.attentionItems.isEmpty {
            lines.append("- 현재 확인이 필요한 항목이 없습니다.")
        } else {
            lines.append(contentsOf: snapshot.attentionItems.prefix(5).map { item in
                "- \(item.title): \(item.detail)"
            })
        }
        return lines.joined(separator: "\n")
    }
}

enum SpreadsheetPlanResultFormatter {
    nonisolated static func estimatedColumnCount(_ row: String) -> Int {
        let separators: [Character] = ["\t", ",", "|"]
        return separators
            .map { separator in row.split(separator: separator, omittingEmptySubsequences: false).count }
            .max() ?? 0
    }

    nonisolated static func body(source: String, rowCount: Int, columnGuess: Int) -> String {
        """
        # 표 정리 계획

        ## 1. 입력 진단
        - 감지한 행: \(rowCount)개
        - 추정 열: \(columnGuess > 0 ? "\(columnGuess)개" : "미확인")
        - 현재 단계에서는 파일 저장 성공을 주장하지 않고, 정리 계획과 검산 기준만 생성합니다.

        ## 2. 정리 순서
        - 헤더 행을 하나로 확정합니다.
        - 빈 행과 합계 행을 분리합니다.
        - 날짜, 금액, 수량, 비율 열의 형식을 통일합니다.
        - 중복 키와 누락 값을 표시합니다.

        ## 3. 검산 기준
        - 원본 행 수와 정리 후 행 수를 비교합니다.
        - 금액 합계가 바뀌었는지 확인합니다.
        - 필수 열이 비어 있는 행을 따로 모읍니다.

        ## 4. 보고용 변환
        - 요약 표, 이상치 표, 확인 필요 표로 나눕니다.
        - 숫자 근거가 없는 결론은 작성하지 않습니다.

        ## 참고 입력
        \(source)
        """
    }
}

enum GoogleSheetsResultFormatter {
    nonisolated static func resultState(_ result: GoogleSheetsReadResult) -> ToolExecutionState {
        if result.values.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "시트 값이 없습니다",
                summary: "\(result.range) 범위에서 값을 찾지 못했습니다.",
                sourceLabel: "Google Sheets 읽기",
                body: nil,
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "범위 바꾸기", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "Google Sheets 값을 읽었습니다",
            summary: "\(result.range) 범위에서 \(result.rowCount)행, \(result.columnCount)열을 가져왔습니다.",
            sourceLabel: "Google Sheets 읽기",
            body: tableBody(result),
            items: [
                MyTeamToolResultItem(
                    id: "rows",
                    title: "행",
                    subtitle: "\(result.rowCount)개",
                    metadata: "최대 20행 미리보기",
                    sourceURL: nil
                ),
                MyTeamToolResultItem(
                    id: "columns",
                    title: "열",
                    subtitle: "\(result.columnCount)개",
                    metadata: result.range,
                    sourceURL: nil
                )
            ],
            nextActions: [
                MyTeamNextAction(id: "changeKeyword", title: "다른 시트 읽기", role: .normal)
            ]
        ))
    }

    nonisolated static func tableBody(_ result: GoogleSheetsReadResult) -> String {
        let previewRows = result.values.prefix(20)
        let lines = previewRows.map { row in
            row.map { cell in
                cell.replacingOccurrences(of: "\n", with: " ")
            }
            .joined(separator: " | ")
        }
        return ([
            "# Google Sheets 읽기",
            "",
            "- 범위: \(result.range)",
            "- 행: \(result.rowCount)",
            "- 열: \(result.columnCount)",
            "",
            "## 미리보기"
        ] + lines.map { "- \($0)" }).joined(separator: "\n")
    }
}

enum CalendarResultFormatter {
    nonisolated static func body(from items: [DailyCalendarBriefingItem]) -> String {
        var lines = [
            "# 오늘 일정",
            ""
        ]
        lines.append(contentsOf: items.prefix(10).map { item in
            let detail = [item.timeText, item.location].compactMap { $0 }.joined(separator: " · ")
            return detail.isEmpty ? "- \(item.title)" : "- \(item.title) · \(detail)"
        })
        return lines.joined(separator: "\n")
    }
}

enum GoogleCalendarResultFormatter {
    nonisolated static func resultState(
        items: [DailyCalendarBriefingItem],
        statusMessage: String
    ) -> ToolExecutionState {
        if items.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "오늘 일정이 없습니다",
                summary: statusMessage,
                sourceLabel: "Google Calendar",
                body: nil,
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "오늘 일정을 가져왔습니다",
            summary: statusMessage,
            sourceLabel: "Google Calendar",
            body: CalendarResultFormatter.body(from: items),
            items: items.prefix(5).map { item in
                MyTeamToolResultItem(
                    id: item.id.uuidString,
                    title: item.title,
                    subtitle: [item.timeText, item.location].compactMap { $0 }.joined(separator: " · "),
                    metadata: "Google Calendar",
                    sourceURL: nil
                )
            },
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
            ]
        ))
    }
}

enum DARTResultFormatter {
    nonisolated static func resultState(
        resolution: DARTCompanyResolution,
        daysBack: Int,
        items: [DARTDisclosureDirectItem],
        sourceLabel: String,
        modeNotice: String
    ) -> ToolExecutionState {
        let displayName = resolution.displayName
        if items.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "조회된 공시가 없습니다",
                summary: "OpenDART가 '\(displayName)' 기준 최근 \(daysBack)일 조회 결과 없음 상태를 반환했습니다.",
                sourceLabel: sourceLabel,
                body: bodyNotice(modeNotice: modeNotice, resolution: resolution),
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "extendRange", title: "기간 늘리기", role: .normal),
                    MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "DART 공시 목록을 가져왔습니다",
            summary: "\(displayName) 최근 \(daysBack)일 기준 공시 \(items.count)건을 찾았습니다.",
            sourceLabel: sourceLabel,
            body: bodyNotice(modeNotice: modeNotice, resolution: resolution),
            items: items.prefix(5).map { item in
                MyTeamToolResultItem(
                    id: item.receiptNumber,
                    title: item.reportName,
                    subtitle: [item.corporationName, item.stockCode].compactMap { $0 }.joined(separator: " · "),
                    metadata: itemMetadata(item),
                    sourceURL: item.sourceURL
                )
            },
            nextActions: [
                MyTeamNextAction(id: "draftReport", title: "보고서 문단", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
            ]
        ))
    }

    private nonisolated static func bodyNotice(modeNotice: String, resolution: DARTCompanyResolution) -> String {
        var lines = [modeNotice]
        if let corpCode = resolution.corpCode {
            lines.append("조회 대상: \(resolution.displayName) · corpCode \(corpCode)")
        }
        lines.append("해석 방식: \(resolutionLabel(resolution.resolutionSource))")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func resolutionLabel(_ source: DARTCompanyResolutionSource) -> String {
        switch source {
        case .directCorpCode:
            return "OpenDART 고유번호 직접 입력"
        case .stockCodeCache:
            return "종목코드 seed"
        case .companyNameCache:
            return "회사명 seed"
        case .manualSeed:
            return "내장 seed"
        case .notFound:
            return "미해석"
        }
    }

    private nonisolated static func itemMetadata(_ item: DARTDisclosureDirectItem) -> String {
        let remark = item.remark?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remarkLabel = remark.flatMap { $0.isEmpty ? nil : "비고 \($0)" }
        return [
            "접수일 \(item.receiptDate)",
            item.submitterName.map { "제출자 \($0)" },
            remarkLabel
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

enum NewsResultFormatter {
    nonisolated static func resultState(
        query: String,
        items: [NaverNewsDirectItem],
        sourceLabel: String,
        modeNotice: String
    ) -> ToolExecutionState {
        if items.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "뉴스 검색 결과가 없습니다",
                summary: "'\(query)' 기준 뉴스 검색 결과를 찾지 못했습니다.",
                sourceLabel: sourceLabel,
                body: modeNotice,
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "뉴스 검색 결과를 정리했습니다",
            summary: "\(query) 관련 최신 뉴스 \(items.count)건의 제목과 설명을 기준으로 공통 이슈를 묶었습니다.",
            sourceLabel: sourceLabel,
            body: briefingBody(query: query, items: items, notice: modeNotice),
            items: items.prefix(5).map { item in
                MyTeamToolResultItem(
                    id: item.sourceURL.absoluteString,
                    title: item.title,
                    subtitle: item.description.isEmpty ? "설명 없음" : item.description,
                    metadata: [
                        item.sourceDomain,
                        item.publishedAt.map(displayDate) ?? "발행일 미확인"
                    ].joined(separator: " · "),
                    sourceURL: item.sourceURL
                )
            },
            nextActions: [
                MyTeamNextAction(id: "draftEvidence", title: "근거 정리", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal),
                MyTeamNextAction(id: "openConnection", title: "개인 키 설정", role: .normal)
            ]
        ))
    }

    private nonisolated static func briefingBody(query: String, items: [NaverNewsDirectItem], notice: String) -> String {
        var lines: [String] = [
            "## 뉴스 검색 결과 기반 브리핑",
            "",
            "- 검색어: \(query)",
            "- 결과 수: \(items.count)건",
            "- 주의: \(notice)",
            "",
            "## 주요 기사"
        ]

        for (index, item) in items.prefix(10).enumerated() {
            lines.append("\(index + 1). \(item.title)")
            if !item.description.isEmpty {
                lines.append("   - 설명: \(item.description)")
            }
            lines.append("   - 출처: \(item.sourceDomain)")
            lines.append("   - 링크: \(item.sourceURL.absoluteString)")
        }

        lines.append("")
        lines.append("## 확인할 점")
        lines.append("- 이 내용은 검색 결과의 제목과 설명에서 확인 가능한 범위만 정리한 것입니다.")
        lines.append("- 구체적인 사실관계와 세부 맥락은 각 원문 링크에서 확인하세요.")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum WeatherResultFormatter {
    nonisolated static func resultState(
        regionName: String,
        nx: Int,
        ny: Int,
        observations: [KMAWeatherDirectObservation],
        sourceLabel: String,
        modeNotice: String
    ) -> ToolExecutionState {
        let summaryParts = summaryParts(from: observations)
        return .succeeded(MyTeamToolResult(
            title: observations.isEmpty ? "날씨 조회 결과가 없습니다" : "현재 날씨를 확인했습니다",
            summary: observations.isEmpty
                ? "\(regionName) 격자 \(nx),\(ny) 기준 기상청 결과를 찾지 못했습니다."
                : (summaryParts.isEmpty ? "기상청 초단기실황 \(observations.count)개 항목을 가져왔습니다." : summaryParts.joined(separator: " · ")),
            sourceLabel: sourceLabel,
            body: modeNotice,
            items: observations.prefix(5).map { observation in
                MyTeamToolResultItem(
                    id: "\(observation.category)-\(observation.baseDate)-\(observation.baseTime)",
                    title: title(for: observation.category),
                    subtitle: "\(observation.value)\(unit(for: observation.category))",
                    metadata: "\(regionName) · 기준 \(observation.baseDate) \(observation.baseTime) · 격자 \(nx),\(ny)",
                    sourceURL: URL(string: "https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do?publicDataPk=15084084")
                )
            },
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "다시 조회", role: .normal),
                MyTeamNextAction(id: "changeKeyword", title: "지역 바꾸기", role: .normal)
            ]
        ))
    }

    private nonisolated static func summaryParts(from observations: [KMAWeatherDirectObservation]) -> [String] {
        observations.compactMap { observation in
            switch observation.category {
            case "T1H":
                return "기온 \(observation.value)℃"
            case "RN1":
                return "1시간 강수량 \(observation.value)mm"
            case "REH":
                return "습도 \(observation.value)%"
            case "WSD":
                return "풍속 \(observation.value)m/s"
            default:
                return nil
            }
        }
    }

    private nonisolated static func title(for category: String) -> String {
        switch category {
        case "T1H": return "기온"
        case "RN1": return "1시간 강수량"
        case "UUU": return "동서바람성분"
        case "VVV": return "남북바람성분"
        case "REH": return "습도"
        case "PTY": return "강수형태"
        case "VEC": return "풍향"
        case "WSD": return "풍속"
        default: return category
        }
    }

    private nonisolated static func unit(for category: String) -> String {
        switch category {
        case "T1H": return "℃"
        case "RN1": return "mm"
        case "REH": return "%"
        case "WSD", "UUU", "VVV": return "m/s"
        case "VEC": return "°"
        default: return ""
        }
    }
}

enum FinanceResultFormatter {
    nonisolated static func resultState(
        label: String,
        query: String,
        response: MyTeamProxyPublicDataResponse,
        sourceLabel: String,
        modeNotice: String
    ) -> ToolExecutionState {
        let items = response.items
        let kind = displayKind(for: response.route)
        return .succeeded(MyTeamToolResult(
            title: "\(label)을 확인했습니다",
            summary: summary(kind: kind, query: query, items: items),
            sourceLabel: sourceLabel,
            body: body(label: label, query: query, notice: modeNotice, kind: kind, items: items),
            items: items.prefix(5).enumerated().map { index, item in
                MyTeamToolResultItem(
                    id: "\(response.route)-\(index)",
                    title: title(from: item, route: response.route, fallback: "\(label) \(index + 1)"),
                    subtitle: subtitle(from: item, route: response.route),
                    metadata: metadata(from: item, route: response.route),
                    sourceURL: URL(string: "https://www.data.go.kr/")
                )
            },
            nextActions: [
                MyTeamNextAction(id: "draftEvidence", title: "보고 문장", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 조회", role: .normal),
                MyTeamNextAction(id: "openConnection", title: "개인 키 설정", role: .normal)
            ]
        ))
    }

    nonisolated static func noResultsState(
        label: String,
        query: String,
        sourceLabel: String
    ) -> ToolExecutionState {
        .succeeded(MyTeamToolResult(
            title: "\(label) 결과가 없습니다",
            summary: "'\(query)' 기준 공공데이터 조회 결과를 찾지 못했습니다.",
            sourceLabel: sourceLabel,
            body: "공공데이터포털 기준일 데이터입니다. 실시간 시세나 투자 조언이 아닙니다.",
            items: [],
            nextActions: [
                MyTeamNextAction(id: "changeKeyword", title: "검색어 바꾸기", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 조회", role: .normal)
            ]
        ))
    }

    nonisolated static func companyNoSummaryState(
        company: String,
        crno: String,
        businessYear: String,
        sourceLabel: String,
        notice: String
    ) -> ToolExecutionState {
        .succeeded(MyTeamToolResult(
            title: "기업 재무 요약 결과가 없습니다",
            summary: "\(company) 법인등록번호 \(crno), 사업연도 \(businessYear) 기준 요약재무제표 결과를 찾지 못했습니다.",
            sourceLabel: sourceLabel,
            body: """
            # 기업 재무 요약

            - 회사: \(company)
            - 법인등록번호: \(crno)
            - 사업연도: \(businessYear)
            - 조회 단계: \(notice)
            - 해석: 공공데이터포털 기업 재무정보 기준 결과가 비어 있습니다. 다른 사업연도를 입력해 보세요.
            """,
            items: [],
            nextActions: [
                MyTeamNextAction(id: "changeKeyword", title: "사업연도 바꾸기", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 조회", role: .normal)
            ]
        ))
    }

    private enum FinanceDisplayKind {
        case krxItems
        case stockPrices
        case stockIndex
        case companySummary
        case generic(String)

        nonisolated var routeName: String {
            switch self {
            case .krxItems: return "krx-items"
            case .stockPrices: return "stock-prices"
            case .stockIndex: return "stock-index"
            case .companySummary: return "company-summary"
            case .generic(let route): return route
            }
        }
    }

    private nonisolated static func displayKind(for route: String) -> FinanceDisplayKind {
        switch route {
        case "krx-items":
            return .krxItems
        case "stock-prices":
            return .stockPrices
        case "stock-index":
            return .stockIndex
        case "company-summary":
            return .companySummary
        default:
            return .generic(route)
        }
    }

    private nonisolated static func body(
        label: String,
        query: String,
        notice: String,
        kind: FinanceDisplayKind,
        items: [[String: String]]
    ) -> String {
        var lines = [
            "# \(label)",
            "",
            "- 조회어: \(query)",
            "- 주의: \(notice)",
            "- 해석: 기준일 공공데이터이며 실시간 시세나 투자 조언이 아닙니다.",
        ]

        guard !items.isEmpty else {
            return lines.joined(separator: "\n")
        }

        lines.append("")
        lines.append("## 핵심 결과")

        if let first = items.first {
            for line in primaryLines(kind: kind, item: first) {
                lines.append("- \(line)")
            }
        }

        let extraItems = Array(items.dropFirst().prefix(4))
        if !extraItems.isEmpty {
            lines.append("")
            lines.append("## 추가 기준일 항목")
            for (index, item) in extraItems.enumerated() {
                lines.append("\(index + 1). \(title(from: item, route: kind.routeName, fallback: "항목"))")
                let details = compactDetails(kind: kind, item: item)
                for detail in details {
                    lines.append("   - \(detail)")
                }
            }
        }

        lines.append("")
        lines.append("## 고지")
        lines.append("- 금융위원회 기준일 공공데이터이며 실시간 시세가 아닙니다.")
        lines.append("- 투자 조언이 아닙니다.")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func summary(kind: FinanceDisplayKind, query: String, items: [[String: String]]) -> String {
        guard let first = items.first else {
            return "'\(query)' 기준 공공데이터 조회 결과를 찾지 못했습니다."
        }
        switch kind {
        case .krxItems:
            return "\(query) 상장종목 정보를 정리했습니다. 기준일 공공데이터이며 실시간 시세가 아닙니다."
        case .stockPrices:
            let date = displayDate(first["basDt"] ?? "-")
            let close = first["clpr"].map(formatNumberString) ?? "-"
            return "\(query) 기준일 시세를 정리했습니다. 기준일 \(date), 종가 \(close)입니다."
        case .stockIndex:
            let date = displayDate(first["basDt"] ?? "-")
            let close = first["clpr"].map(formatNumberString) ?? "-"
            return "\(query) 시장 지수 기준일 정보를 정리했습니다. 기준일 \(date), 종가 \(close)입니다."
        case .companySummary:
            let year = first["bizYear"] ?? query
            return "기업 재무 요약 \(items.count)건을 정리했습니다. 사업연도 \(year) 기준 공공데이터입니다."
        case .generic:
            return "\(query) 기준 공공데이터 \(items.count)건을 가져왔습니다. 실시간 시세가 아닙니다."
        }
    }

    private nonisolated static func title(from item: [String: String], route: String, fallback: String) -> String {
        switch displayKind(for: route) {
        case .krxItems, .stockPrices:
            return item["itmsNm"] ?? item["corpNm"] ?? fallback
        case .stockIndex:
            return item["idxNm"] ?? fallback
        case .companySummary:
            return item["accountNm"] ?? item["fnclDcdNm"] ?? fallback
        case .generic:
            return [
                "itmsNm", "idxNm", "corpNm", "crno", "isinCd", "srtnCd", "basDt"
            ].compactMap { item[$0] }.first ?? fallback
        }
    }

    private nonisolated static func subtitle(from item: [String: String], route: String) -> String? {
        switch displayKind(for: route) {
        case .krxItems:
            return [
                item["srtnCd"].map { "단축코드 \($0)" },
                item["mrktCtg"].map { "시장 \($0)" },
                item["isinCd"].map { "ISIN \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        case .stockPrices:
            return [
                item["clpr"].map { "종가 \(formatNumberString($0))" },
                item["vs"].map { "전일대비 \(formatSignedNumberString($0))" },
                item["fltRt"].map { "등락률 \(appendPercentIfNeeded($0))" }
            ].compactMap(\.self).joined(separator: " · ")
        case .stockIndex:
            return [
                item["clpr"].map { "종가 \(formatNumberString($0))" },
                item["vs"].map { "전일대비 \(formatSignedNumberString($0))" },
                item["fltRt"].map { "등락률 \(appendPercentIfNeeded($0))" }
            ].compactMap(\.self).joined(separator: " · ")
        case .companySummary:
            return [
                item["bizYear"].map { "사업연도 \($0)" },
                item["fnclDcdNm"].map { "구분 \($0)" },
                item["accountNm"].map { "항목 \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        case .generic:
            return [
                item["clpr"].map { "종가 \($0)" },
                item["mkp"].map { "시가 \($0)" },
                item["fltRt"].map { "등락률 \($0)" },
                item["trqu"].map { "거래량 \($0)" },
                item["idxCsf"].map { "분류 \($0)" }
            ].compactMap(\.self).prefix(3).joined(separator: " · ")
        }
    }

    private nonisolated static func metadata(from item: [String: String], route: String) -> String? {
        switch displayKind(for: route) {
        case .krxItems:
            return [
                item["basDt"].map { "기준일 \(displayDate($0))" },
                item["corpNm"].map { "법인명 \($0)" },
                item["crno"].map { "법인등록번호 \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        case .stockPrices, .stockIndex:
            return [
                item["basDt"].map { "기준일 \(displayDate($0))" },
                item["mrktCtg"].map { "시장 \($0)" },
                item["idxCsf"].map { "분류 \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        case .companySummary:
            return [
                item["bizYear"].map { "사업연도 \($0)" },
                item["crno"].map { "법인등록번호 \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        case .generic:
            return [
                item["basDt"].map { "기준일 \($0)" },
                item["mrktCtg"].map { "시장 \($0)" },
                item["bizYear"].map { "사업연도 \($0)" }
            ].compactMap(\.self).joined(separator: " · ")
        }
    }

    private nonisolated static func primaryLines(kind: FinanceDisplayKind, item: [String: String]) -> [String] {
        switch kind {
        case .krxItems:
            return [
                item["basDt"].map { "기준일: \(displayDate($0))" },
                item["itmsNm"].map { "종목명: \($0)" },
                item["srtnCd"].map { "단축코드: \($0)" },
                item["isinCd"].map { "ISIN: \($0)" },
                item["mrktCtg"].map { "시장: \($0)" },
                item["crno"].map { "법인등록번호: \($0)" },
                item["corpNm"].map { "법인명: \($0)" }
            ].compactMap(\.self)
        case .stockPrices:
            return [
                item["basDt"].map { "기준일: \(displayDate($0))" },
                item["itmsNm"].map { "종목명: \($0)" },
                item["clpr"].map { "종가: \(formatNumberString($0))" },
                item["vs"].map { "전일대비: \(formatSignedNumberString($0))" },
                item["fltRt"].map { "등락률: \(appendPercentIfNeeded($0))" },
                item["mkp"].map { "시가: \(formatNumberString($0))" },
                item["hipr"].map { "고가: \(formatNumberString($0))" },
                item["lopr"].map { "저가: \(formatNumberString($0))" },
                item["trqu"].map { "거래량: \(formatNumberString($0))" },
                item["mrktCtg"].map { "시장: \($0)" }
            ].compactMap(\.self)
        case .stockIndex:
            return [
                item["basDt"].map { "기준일: \(displayDate($0))" },
                item["idxNm"].map { "지수명: \($0)" },
                item["clpr"].map { "종가: \(formatNumberString($0))" },
                item["vs"].map { "전일대비: \(formatSignedNumberString($0))" },
                item["fltRt"].map { "등락률: \(appendPercentIfNeeded($0))" },
                item["trqu"].map { "거래량: \(formatNumberString($0))" },
                item["trPrc"].map { "거래대금: \(formatNumberString($0))" }
            ].compactMap(\.self)
        case .companySummary:
            return [
                item["bizYear"].map { "사업연도: \($0)" },
                item["fnclDcdNm"].map { "재무제표 구분: \($0)" },
                item["accountNm"].map { "계정과목: \($0)" },
                item["thstrmAmount"].map { "당기금액: \(formatNumberString($0))" },
                item["frmtrmAmount"].map { "전기금액: \(formatNumberString($0))" },
                item["bfefrmtrmAmount"].map { "전전기금액: \(formatNumberString($0))" }
            ].compactMap(\.self)
        case .generic:
            return item.sorted(by: { $0.key < $1.key }).prefix(8).map { "\($0.key): \($0.value)" }
        }
    }

    private nonisolated static func compactDetails(kind: FinanceDisplayKind, item: [String: String]) -> [String] {
        switch kind {
        case .krxItems:
            return [
                item["basDt"].map { "기준일 \(displayDate($0))" },
                item["srtnCd"].map { "단축코드 \($0)" },
                item["mrktCtg"].map { "시장 \($0)" }
            ].compactMap(\.self)
        case .stockPrices:
            return [
                item["basDt"].map { "기준일 \(displayDate($0))" },
                item["clpr"].map { "종가 \(formatNumberString($0))" },
                item["fltRt"].map { "등락률 \(appendPercentIfNeeded($0))" }
            ].compactMap(\.self)
        case .stockIndex:
            return [
                item["basDt"].map { "기준일 \(displayDate($0))" },
                item["clpr"].map { "종가 \(formatNumberString($0))" },
                item["fltRt"].map { "등락률 \(appendPercentIfNeeded($0))" }
            ].compactMap(\.self)
        case .companySummary:
            return [
                item["accountNm"].map { "계정과목 \($0)" },
                item["thstrmAmount"].map { "당기금액 \(formatNumberString($0))" },
                item["frmtrmAmount"].map { "전기금액 \(formatNumberString($0))" }
            ].compactMap(\.self)
        case .generic:
            return item.sorted(by: { $0.key < $1.key }).prefix(3).map { "\($0.key) \($0.value)" }
        }
    }

    private nonisolated static func displayDate(_ raw: String) -> String {
        guard raw.count == 8 else { return raw }
        let year = raw.prefix(4)
        let month = raw.dropFirst(4).prefix(2)
        let day = raw.suffix(2)
        return "\(year)-\(month)-\(day)"
    }

    private nonisolated static func formatNumberString(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: "")
        guard let number = Int64(normalized) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? raw
    }

    private nonisolated static func formatSignedNumberString(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: "")
        guard let number = Int64(normalized) else { return raw }
        let prefix = number > 0 ? "+" : ""
        return "\(prefix)\(formatNumberString(String(number)))"
    }

    private nonisolated static func appendPercentIfNeeded(_ raw: String) -> String {
        raw.contains("%") ? raw : "\(raw)%"
    }
}

enum LawResultFormatter {
    nonisolated static func resultState(
        query: String,
        results: [KoreanLawResult],
        sourceLabel: String,
        modeNotice: String
    ) -> ToolExecutionState {
        if results.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "법령 검색 결과가 없습니다",
                summary: "'\(query)' 기준 공식 법령 검색 결과를 찾지 못했습니다.",
                sourceLabel: sourceLabel,
                body: modeNotice,
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "공식 법령 검색 결과입니다",
            summary: "법률 자문이 아닌 공식 출처 기반 검색 결과 \(results.count)건입니다. 조문 검증은 별도 확인이 필요합니다.",
            sourceLabel: sourceLabel,
            body: modeNotice,
            items: results.prefix(5).map { result in
                MyTeamToolResultItem(
                    id: "\(result.lawName)-\(result.effectiveDate ?? "unknown")",
                    title: result.lawName,
                    subtitle: result.summary,
                    metadata: [
                        result.effectiveDate.map { "시행일 \($0)" },
                        "검증 상태 \(result.verificationStatus)"
                    ].compactMap(\.self).joined(separator: " · "),
                    sourceURL: result.officialSourceURL
                )
            },
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal),
                MyTeamNextAction(id: "openSource", title: "원문 확인", role: .normal)
            ]
        ))
    }
}
