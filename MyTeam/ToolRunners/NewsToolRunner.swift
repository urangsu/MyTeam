import Foundation

enum NewsToolRunner {
    static func run(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.naverNews
        guard let query = requiredQuery(input.query) else {
            return .failed(MyTeamToolFailure(
                title: "뉴스 검색어가 필요합니다",
                message: "회사명, 산업, 키워드처럼 확인할 뉴스 주제를 입력해 주세요. 예: 삼성전자 뉴스, 리튬 관련 뉴스.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "검색어 입력", role: .normal)
                ]
            ))
        }
        guard query.count >= 2 else {
            return .failed(MyTeamToolFailure(
                title: "검색어가 짧습니다",
                message: "뉴스 검색어는 두 글자 이상 입력하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "검색어 바꾸기", role: .normal)
                ]
            ))
        }

        let displayCount = min(max(input.displayCount ?? 10, 1), 20)

        do {
            let response = try await MyTeamBasicLookupProxyClient.shared.searchNews(
                query: query,
                display: displayCount
            )
            return NewsResultFormatter.resultState(
                query: query,
                items: response.directItems,
                sourceLabel: "MyTeam 기본 뉴스 조회 · Naver News Search",
                modeNotice: "이 브리핑은 뉴스 검색 결과의 제목과 설명을 기준으로 정리한 것입니다. 기사 전문은 원문 링크에서 확인하세요."
            )
        } catch {
            if
                let clientID = credentialValue(provider: provider, fieldID: "clientID"),
                let clientSecret = credentialValue(provider: provider, fieldID: "clientSecret")
            {
                do {
                    let items = try await NaverNewsDirectConnector.search(
                        query: query,
                        clientID: clientID,
                        clientSecret: clientSecret,
                        display: displayCount
                    )
                    return NewsResultFormatter.resultState(
                        query: query,
                        items: items,
                        sourceLabel: "Naver News API · 개인 키",
                        modeNotice: "기본 조회 서버가 응답하지 않아 개인 Naver API 키로 조회했습니다. 이 브리핑은 뉴스 검색 결과의 제목과 설명을 기준으로 정리한 것입니다. 기사 전문은 원문 링크에서 확인하세요."
                    )
                } catch {
                    return .failed(MyTeamToolFailure(
                        title: "뉴스 조회를 완료하지 못했습니다",
                        message: "기본 조회 서버와 개인 Naver API 키 조회가 모두 실패했습니다. 잠시 후 다시 시도하거나 개인 키 권한을 확인하세요.",
                        recoveryActions: [
                            MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                            MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                        ]
                    ))
                }
            }

            return .failed(MyTeamToolFailure(
                title: "뉴스 조회를 완료하지 못했습니다",
                message: "기본 조회 서버가 응답하지 않습니다. 잠시 후 다시 시도하거나 개인 Naver API 키를 연결하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                    MyTeamNextAction(id: "openConnection", title: "개인 키 연결", role: .normal)
                ]
            ))
        }
    }

    private static func requiredQuery(_ query: String?) -> String? {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static func credentialValue(provider: ExternalProvider, fieldID: String) -> String? {
        guard
            let field = provider.credentialSchema.fields.first(where: { $0.id == fieldID }),
            let value = SecureCredentialStore.shared.read(provider: provider, field: field)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
