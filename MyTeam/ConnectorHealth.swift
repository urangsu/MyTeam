import Combine
import Foundation

enum ConnectorStatus: Codable, Sendable, Equatable {
    case available
    case unavailable(reason: String)
    case needsSetup(reason: String)
    case approvalRequired
    case degraded(reason: String)

    var label: String {
        switch self {
        case .available:
            return "available"
        case .unavailable:
            return "unavailable"
        case .needsSetup:
            return "needsSetup"
        case .approvalRequired:
            return "approvalRequired"
        case .degraded:
            return "degraded"
        }
    }

    var reason: String? {
        switch self {
        case .available, .approvalRequired:
            return nil
        case .unavailable(let reason), .needsSetup(let reason), .degraded(let reason):
            return reason
        }
    }

    var isOperational: Bool {
        switch self {
        case .available, .degraded, .approvalRequired:
            return true
        case .unavailable, .needsSetup:
            return false
        }
    }
}

struct ConnectorHealth: Codable, Sendable, Equatable {
    let stockQuote: ConnectorStatus
    let newsSearch: ConnectorStatus
    let disclosureSearch: ConnectorStatus
    let webFetch: ConnectorStatus
    let pdfText: ConnectorStatus
    let imageOCR: ConnectorStatus
    let mailRead: ConnectorStatus
    let calendarDraft: ConnectorStatus
    let mapsSearch: ConnectorStatus
    let trainSearch: ConnectorStatus

    var dartSearch: ConnectorStatus { disclosureSearch }
    var calendarWrite: ConnectorStatus { calendarDraft }

    static func current() -> ConnectorHealth {
        ConnectorRegistry.shared.currentHealth()
    }
}

final class ConnectorRegistry: ObservableObject {
    static let shared = ConnectorRegistry()

    @Published private(set) var lastHealth: ConnectorHealth = ConnectorRegistry.defaultHealth()

    static func defaultHealth() -> ConnectorHealth {
        ConnectorHealth(
            stockQuote: quoteConnectorStatus(),
            newsSearch: newsSearchStatus(),
            disclosureSearch: disclosureSearchStatus(),
            webFetch: webFetchStatus(),
            pdfText: .available,
            imageOCR: .available,
            mailRead: .needsSetup(reason: "메일 계정 연결이 필요합니다."),
            calendarDraft: .approvalRequired,
            mapsSearch: webFetchStatus(),
            trainSearch: .needsSetup(reason: "열차 조회 연동이 아직 설정되지 않았습니다.")
        )
    }

    private static func quoteConnectorStatus() -> ConnectorStatus {
        let hasQuoteLookupTool = AgentToolRegistry.shared.tools["finance_quote"] != nil
        return hasQuoteLookupTool
            ? .degraded(reason: "시세 조회는 웹 폴백으로만 동작합니다.")
            : .needsSetup(reason: "시세 조회 커넥터가 설정되지 않았습니다.")
    }

    private static func newsSearchStatus() -> ConnectorStatus {
        let hasWebSearchTool = AgentToolRegistry.shared.tools["web_search"] != nil
        return hasWebSearchTool
            ? .available
            : .needsSetup(reason: "뉴스 검색용 웹 커넥터가 설정되지 않았습니다.")
    }

    private static func disclosureSearchStatus() -> ConnectorStatus {
        let hasWebSearchTool = AgentToolRegistry.shared.tools["web_search"] != nil
        return hasWebSearchTool
            ? .degraded(reason: "공시는 DART/KIND 전용 커넥터가 없어 웹 폴백으로만 동작합니다.")
            : .needsSetup(reason: "DART/KIND 공시 커넥터가 설정되지 않았습니다.")
    }

    private static func webFetchStatus() -> ConnectorStatus {
        let hasWebSearchTool = AgentToolRegistry.shared.tools["web_search"] != nil
        return hasWebSearchTool
            ? .available
            : .needsSetup(reason: "웹 조회 커넥터가 설정되지 않았습니다.")
    }

    func refresh() {
        lastHealth = currentHealth()
    }

    func currentHealth() -> ConnectorHealth {
        let hasGemini = !(KeychainManager.load(key: "geminiAPIKey") ?? "").isEmpty
        let hasOpenAI = !(KeychainManager.load(key: "openAIAPIKey") ?? "").isEmpty
        let hasClaude = !(KeychainManager.load(key: "claudeAPIKey") ?? "").isEmpty
        let hasOpenRouter = !(KeychainManager.load(key: "openRouterAPIKey") ?? "").isEmpty
        let hasWeb = hasGemini || hasOpenAI || hasClaude || hasOpenRouter

        return ConnectorHealth(
            stockQuote: Self.quoteConnectorStatus(),
            newsSearch: Self.newsSearchStatus(),
            disclosureSearch: Self.disclosureSearchStatus(),
            webFetch: Self.webFetchStatus(),
            pdfText: .available,
            imageOCR: .available,
            mailRead: .needsSetup(reason: "Gmail 또는 Mail 읽기 연결이 필요합니다."),
            calendarDraft: .approvalRequired,
            mapsSearch: hasWeb ? .available : .degraded(reason: "지도 검색은 가능하지만 출처 검증이 약합니다."),
            trainSearch: .needsSetup(reason: "열차 조회 API 또는 공식 검색 연결이 필요합니다.")
        )
    }
}
