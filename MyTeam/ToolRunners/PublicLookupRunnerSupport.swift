import Foundation

enum PublicLookupRunnerSupport {
    struct FinanceFetchResult: Sendable {
        let response: MyTeamProxyPublicDataResponse
        let sourceLabel: String
        let modeNotice: String
    }

    static func requiredQuery(_ query: String?) -> String? {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func credentialValue(provider: ExternalProvider, fieldID: String) -> String? {
        guard
            let field = provider.credentialSchema.fields.first(where: { $0.id == fieldID }),
            let value = SecureCredentialStore.shared.read(provider: provider, field: field)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    static func fetchFinanceData(path: String, query: String, display: Int) async throws -> FinanceFetchResult {
        do {
            let response = try await MyTeamBasicLookupProxyClient.shared.fetchFinance(
                path: path,
                query: query,
                display: display
            )
            return FinanceFetchResult(
                response: response,
                sourceLabel: "MyTeam 기본 공공데이터 조회",
                modeNotice: response.notice ?? "공공데이터포털 기준일 데이터입니다. 실시간 시세나 투자 조언이 아닙니다."
            )
        } catch MyTeamProxyError.noResults {
            throw MyTeamProxyError.noResults
        } catch {
            guard let serviceKey = credentialValue(provider: .publicDataPortal, fieldID: "serviceKey") else {
                throw error
            }
            let direct = try await PublicDataPortalDirectConnector.finance(
                path: path,
                query: query,
                serviceKey: serviceKey,
                display: display
            )
            return FinanceFetchResult(
                response: MyTeamProxyPublicDataResponse(
                    ok: true,
                    provider: "public-data-portal",
                    route: direct.route,
                    query: query,
                    count: direct.items.count,
                    elapsedMs: nil,
                    notice: direct.notice,
                    items: direct.items
                ),
                sourceLabel: "공공데이터포털 · 개인 키",
                modeNotice: "기본 조회 서버가 응답하지 않아 개인 Service Key로 조회했습니다. \(direct.notice)"
            )
        }
    }
}
