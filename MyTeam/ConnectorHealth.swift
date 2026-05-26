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

    @Published private(set) var lastHealth: ConnectorHealth = ConnectorHealth(
        stockQuote: .available,
        newsSearch: .unavailable(reason: "공개 검색 커넥터가 아직 설정되지 않았습니다."),
        disclosureSearch: .unavailable(reason: "공개 검색 커넥터가 아직 설정되지 않았습니다."),
        webFetch: .unavailable(reason: "웹 조회 커넥터가 아직 설정되지 않았습니다."),
        pdfText: .available,
        imageOCR: .available,
        mailRead: .needsSetup(reason: "메일 계정 연결이 필요합니다."),
        calendarDraft: .approvalRequired,
        mapsSearch: .available,
        trainSearch: .needsSetup(reason: "열차 조회 연동이 아직 설정되지 않았습니다.")
    )

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
            stockQuote: .available,
            newsSearch: hasWeb ? .available : .unavailable(reason: "웹 검색 모델 키가 없습니다."),
            disclosureSearch: hasWeb ? .available : .unavailable(reason: "공시/뉴스 조회용 모델 키가 없습니다."),
            webFetch: hasWeb ? .available : .unavailable(reason: "웹 조회 모델 키가 없습니다."),
            pdfText: .available,
            imageOCR: .available,
            mailRead: .needsSetup(reason: "Gmail 또는 Mail 읽기 연결이 필요합니다."),
            calendarDraft: .approvalRequired,
            mapsSearch: hasWeb ? .available : .degraded(reason: "지도 검색은 가능하지만 출처 검증이 약합니다."),
            trainSearch: .needsSetup(reason: "열차 조회 API 또는 공식 검색 연결이 필요합니다.")
        )
    }
}
