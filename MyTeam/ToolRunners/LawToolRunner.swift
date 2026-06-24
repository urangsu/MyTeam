import Foundation

enum LawToolRunner {
    static func run(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.koreanLaw
        guard let query = requiredQuery(input.query) else {
            return .failed(MyTeamToolFailure(
                title: "법령 검색어가 필요합니다",
                message: "확인할 법령명, 조문, 또는 쟁점 키워드를 입력해 주세요. 예: 근로기준법 연차, 주52시간.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "검색어 입력", role: .normal)
                ]
            ))
        }

        do {
            let response = try await MyTeamBasicLookupProxyClient.shared.searchKoreanLaw(
                query: query,
                display: input.displayCount ?? 10
            )
            return LawResultFormatter.resultState(
                query: query,
                results: response.directResults,
                sourceLabel: "MyTeam 기본 법령 조회",
                modeNotice: response.notice ?? "법령 검색 결과입니다. 법률 자문이 아니며, 최종 판단은 공식 법령 원문을 확인해야 합니다."
            )
        } catch MyTeamProxyError.noResults {
            return LawResultFormatter.resultState(
                query: query,
                results: [],
                sourceLabel: "MyTeam 기본 법령 조회",
                modeNotice: "법령 검색 결과입니다. 법률 자문이 아니며, 최종 판단은 공식 법령 원문을 확인해야 합니다."
            )
        } catch {
            guard let lawOC = credentialValue(provider: provider, fieldID: "lawOC") else {
                return .failed(MyTeamToolFailure(
                    title: "법령 검색을 완료하지 못했습니다",
                    message: "기본 조회 서버가 응답하지 않습니다. 잠시 후 다시 시도하거나 개인 국가법령정보센터 OC를 연결하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                        MyTeamNextAction(id: "openConnection", title: "개인 키 연결", role: .normal)
                    ]
                ))
            }
            do {
                let results = try await KoreanLawDirectConnector.search(
                    KoreanLawSearchRequest(query: query, lawName: nil, article: nil),
                    lawOC: lawOC
                )
                return LawResultFormatter.resultState(
                    query: query,
                    results: results,
                    sourceLabel: "국가법령정보센터 · 개인 키 · partial",
                    modeNotice: "기본 조회 서버가 응답하지 않아 개인 국가법령정보센터 OC로 조회했습니다. 법률 자문이 아니며, 최종 판단은 공식 법령 원문을 확인해야 합니다."
                )
            } catch {
                return .failed(MyTeamToolFailure(
                    title: "법령 검색을 완료하지 못했습니다",
                    message: "기본 조회 서버와 개인 국가법령정보센터 OC 조회가 모두 실패했습니다. 잠시 후 다시 시도하거나 개인 키 권한을 확인하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                        MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                    ]
                ))
            }
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
