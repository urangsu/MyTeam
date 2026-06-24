import Foundation

enum FinanceToolRunner {
    private struct CompanyFinanceRequest: Sendable {
        let companyQuery: String
        let businessYear: String?
        let directCorporateRegistrationNumber: String?
    }

    static func runStockPrice(input: MyTeamToolInput) async -> ToolExecutionState {
        await runFinance(
            path: "finance/stocks/prices",
            label: "주식 기준일 시세",
            missingTitle: "주식 기준일 시세 입력이 필요합니다",
            missingMessage: "주식 기준일 시세를 조회할 종목명이 필요합니다. 예: 삼성전자, 005930",
            input: input
        )
    }

    static func runMarketIndex(input: MyTeamToolInput) async -> ToolExecutionState {
        await runFinance(
            path: "finance/index/stock",
            label: "시장 지수 기준일 조회",
            missingTitle: "시장 지수 입력이 필요합니다",
            missingMessage: "시장 지수를 조회할 지수명이 필요합니다. 예: 코스피, 코스닥, 코스피200",
            input: input
        )
    }

    static func runCompanyStatement(input: MyTeamToolInput) async -> ToolExecutionState {
        let request = companyFinanceRequest(from: input)
        guard !request.companyQuery.isEmpty || request.directCorporateRegistrationNumber != nil else {
            return .failed(MyTeamToolFailure(
                title: "기업 재무 요약 입력이 필요합니다",
                message: "재무요약을 확인할 회사명과 사업연도가 필요합니다. 예: 삼성전자 2024, 005930 2024",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "입력 바꾸기", role: .normal)
                ]
            ))
        }
        guard let businessYear = request.businessYear else {
            return .failed(MyTeamToolFailure(
                title: "사업연도가 필요합니다",
                message: "재무요약을 확인할 사업연도를 함께 입력해 주세요. 예: 삼성전자 2024, 005930 2024",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "사업연도 입력", role: .normal)
                ]
            ))
        }

        let label = "기업 재무 요약"
        let corporateRegistrationNumber: String
        let resolvedCompanyLabel: String
        let resolverNotice: String

        if let directNumber = request.directCorporateRegistrationNumber {
            corporateRegistrationNumber = directNumber
            resolvedCompanyLabel = directNumber
            resolverNotice = "입력한 법인등록번호로 금융위원회 기업 재무정보를 조회했습니다."
        } else {
            do {
                let listed = try await PublicLookupRunnerSupport.fetchFinanceData(
                    path: "finance/krx/items",
                    query: request.companyQuery,
                    display: 5
                )
                guard let best = bestKRXItem(matching: request.companyQuery, items: listed.response.items) else {
                    return companyFinanceNoCompanyState(query: request.companyQuery, businessYear: businessYear)
                }
                guard let crno = best["crno"], !crno.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .failed(MyTeamToolFailure(
                        title: "법인등록번호를 찾지 못했습니다",
                        message: "KRX 상장종목정보에서 '\(request.companyQuery)' 항목은 찾았지만 기업 재무정보 조회에 필요한 법인등록번호가 비어 있습니다.",
                        recoveryActions: [
                            MyTeamNextAction(id: "changeKeyword", title: "회사명/종목코드 바꾸기", role: .normal),
                            MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                        ]
                    ))
                }
                corporateRegistrationNumber = crno
                resolvedCompanyLabel = companyLabel(from: best, fallback: request.companyQuery)
                resolverNotice = "KRX 상장종목정보에서 \(resolvedCompanyLabel)의 법인등록번호 \(crno)를 확인한 뒤 금융위원회 기업 재무정보를 조회했습니다."
            } catch MyTeamProxyError.noResults {
                return companyFinanceNoCompanyState(query: request.companyQuery, businessYear: businessYear)
            } catch {
                return .failed(MyTeamToolFailure(
                    title: "기업을 확인하지 못했습니다",
                    message: "회사명/종목코드 확인 단계가 실패했습니다. 기본 조회 서버 상태를 확인하거나 공공데이터포털 개인 Service Key를 연결하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                        MyTeamNextAction(id: "openConnection", title: "개인 키 연결", role: .normal)
                    ]
                ))
            }
        }

        let summaryQuery = "\(corporateRegistrationNumber) \(businessYear)"
        do {
            let fetched = try await PublicLookupRunnerSupport.fetchFinanceData(
                path: "finance/company/summary",
                query: summaryQuery,
                display: input.displayCount ?? 10
            )
            guard !fetched.response.items.isEmpty else {
                return FinanceResultFormatter.companyNoSummaryState(
                    company: resolvedCompanyLabel,
                    crno: corporateRegistrationNumber,
                    businessYear: businessYear,
                    sourceLabel: fetched.sourceLabel,
                    notice: resolverNotice
                )
            }
            return FinanceResultFormatter.resultState(
                label: label,
                query: "\(resolvedCompanyLabel) \(businessYear)",
                response: fetched.response,
                sourceLabel: fetched.sourceLabel,
                modeNotice: "\(resolverNotice) \(fetched.modeNotice)"
            )
        } catch MyTeamProxyError.noResults {
            return FinanceResultFormatter.companyNoSummaryState(
                company: resolvedCompanyLabel,
                crno: corporateRegistrationNumber,
                businessYear: businessYear,
                sourceLabel: "MyTeam 기본 공공데이터 조회",
                notice: resolverNotice
            )
        } catch {
            return .failed(MyTeamToolFailure(
                title: "\(label)을 완료하지 못했습니다",
                message: "법인등록번호는 확인했지만 재무요약 조회가 실패했습니다. 사업연도와 공공데이터포털 권한을 확인하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                    MyTeamNextAction(id: "changeKeyword", title: "사업연도 바꾸기", role: .normal),
                    MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                ]
            ))
        }
    }

    private static func runFinance(
        path: String,
        label: String,
        missingTitle: String,
        missingMessage: String,
        input: MyTeamToolInput
    ) async -> ToolExecutionState {
        guard let query = PublicLookupRunnerSupport.requiredQuery(input.query) else {
            return .failed(MyTeamToolFailure(
                title: missingTitle,
                message: missingMessage,
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "검색어 입력", role: .normal)
                ]
            ))
        }
        do {
            let fetched = try await PublicLookupRunnerSupport.fetchFinanceData(
                path: path,
                query: query,
                display: input.displayCount ?? 10
            )
            return FinanceResultFormatter.resultState(
                label: label,
                query: query,
                response: fetched.response,
                sourceLabel: fetched.sourceLabel,
                modeNotice: fetched.modeNotice
            )
        } catch MyTeamProxyError.noResults {
            return FinanceResultFormatter.noResultsState(
                label: label,
                query: query,
                sourceLabel: "MyTeam 기본 공공데이터 조회",
            )
        } catch {
            guard PublicLookupRunnerSupport.credentialValue(provider: .publicDataPortal, fieldID: "serviceKey") != nil else {
                return .failed(MyTeamToolFailure(
                    title: "\(label)을 완료하지 못했습니다",
                    message: "기본 조회 서버가 응답하지 않습니다. 잠시 후 다시 시도하거나 공공데이터포털 개인 Service Key를 연결하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                        MyTeamNextAction(id: "openConnection", title: "개인 키 연결", role: .normal)
                    ]
                ))
            }
            return .failed(MyTeamToolFailure(
                title: "\(label)을 완료하지 못했습니다",
                message: "기본 조회 서버와 공공데이터포털 개인 키 조회가 모두 실패했습니다. 개인 키 권한과 입력값을 확인하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                    MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                ]
            ))
        }
    }

    private static func companyFinanceRequest(from input: MyTeamToolInput) -> CompanyFinanceRequest {
        let raw = input.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tokens = raw.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
        let year = tokens.first { token in
            token.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil
        }
        let directCRNO = tokens.first { token in
            token.range(of: #"^\d{13}$"#, options: .regularExpression) != nil
        }
        let companyTokens = tokens.filter { token in
            token != (year ?? "") && token != (directCRNO ?? "")
        }
        return CompanyFinanceRequest(
            companyQuery: companyTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
            businessYear: year,
            directCorporateRegistrationNumber: directCRNO
        )
    }

    private static func bestKRXItem(matching query: String, items: [[String: String]]) -> [String: String]? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exactCode = items.first(where: { $0["srtnCd"] == trimmed }) {
            return exactCode
        }
        if let exactName = items.first(where: { item in
            item["itmsNm"] == trimmed || item["corpNm"] == trimmed
        }) {
            return exactName
        }
        return items.first
    }

    private static func companyLabel(from item: [String: String], fallback: String) -> String {
        item["itmsNm"] ?? item["corpNm"] ?? item["isinCdNm"] ?? fallback
    }

    private static func companyFinanceNoCompanyState(query: String, businessYear: String) -> ToolExecutionState {
        .failed(MyTeamToolFailure(
            title: "상장종목에서 회사를 찾지 못했습니다",
            message: "'\(query)'로 KRX 상장종목정보를 찾지 못했습니다. 회사명, 6자리 종목코드, 또는 법인등록번호와 사업연도를 입력하세요. 예: 삼성전자 \(businessYear), 005930 \(businessYear)",
            recoveryActions: [
                MyTeamNextAction(id: "changeKeyword", title: "검색어 바꾸기", role: .normal),
                MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
            ]
        ))
    }

}
