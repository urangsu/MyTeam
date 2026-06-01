import Combine
import Foundation

enum ConnectorStatus: Codable, Sendable, Equatable {
    case available
    case unavailable(reason: String)
    case needsSetup(reason: String)
    case approvalRequired
    case degraded(reason: String)

    nonisolated var label: String {
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

    nonisolated var reason: String? {
        switch self {
        case .available, .approvalRequired:
            return nil
        case .unavailable(let reason), .needsSetup(let reason), .degraded(let reason):
            return reason
        }
    }

    nonisolated var isOperational: Bool {
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
    let playwrightMCP: ConnectorStatus
    let browserDOM: ConnectorStatus
    let browserSearch: ConnectorStatus
    let browserClick: ConnectorStatus
    let browserScreenshot: ConnectorStatus

    var dartSearch: ConnectorStatus { disclosureSearch }
    var calendarWrite: ConnectorStatus { calendarDraft }
    static let imageOCRUnavailable: ConnectorStatus = .needsSetup(reason: "이미지 OCR은 아직 준비 중입니다. 텍스트가 포함된 PDF/DOCX/PPTX/XLSX만 읽을 수 있습니다.")

    static let unconfigured = ConnectorHealth(
        stockQuote: .needsSetup(reason: "시세 조회 커넥터가 설정되지 않았습니다."),
        newsSearch: .needsSetup(reason: "뉴스 검색용 웹 커넥터가 설정되지 않았습니다."),
        disclosureSearch: .needsSetup(reason: "DART/KIND 공시 커넥터가 설정되지 않았습니다."),
        webFetch: .needsSetup(reason: "웹 조회 커넥터가 설정되지 않았습니다."),
        pdfText: .available,
        imageOCR: imageOCRUnavailable,
        mailRead: .needsSetup(reason: "메일 계정 연결이 필요합니다."),
        calendarDraft: .approvalRequired,
        mapsSearch: .needsSetup(reason: "지도 조회 커넥터가 설정되지 않았습니다."),
        trainSearch: .needsSetup(reason: "열차 조회 커넥터가 설정되지 않았습니다."),
        playwrightMCP: .needsSetup(reason: "Playwright MCP 상태를 아직 확인하지 않았습니다."),
        browserDOM: .needsSetup(reason: "Playwright MCP snapshot tool을 확인하지 못했습니다."),
        browserSearch: .needsSetup(reason: "Playwright MCP navigate/snapshot tool이 필요합니다."),
        browserClick: .needsSetup(reason: "Playwright MCP click tool을 확인하지 못했습니다."),
        browserScreenshot: .needsSetup(reason: "Playwright MCP screenshot tool을 확인하지 못했습니다.")
    )

    @MainActor
    static func current() -> ConnectorHealth {
        ConnectorRegistry.shared.currentHealth()
    }
}

@MainActor
final class ConnectorRegistry: ObservableObject {
    static let shared = ConnectorRegistry()

    @Published private(set) var lastHealth: ConnectorHealth = ConnectorRegistry.defaultHealth()

    static func defaultHealth() -> ConnectorHealth {
        ConnectorHealth(
            stockQuote: quoteConnectorStatus(),
            newsSearch: newsSearchStatus(hasGroundedSearch: false, hasLocalWebFallback: true),
            disclosureSearch: disclosureSearchStatus(hasGroundedSearch: false, hasLocalWebFallback: true),
            webFetch: webFetchStatus(hasGroundedSearch: false, hasLocalWebFallback: true),
            pdfText: .available,
            imageOCR: ConnectorHealth.imageOCRUnavailable,
            mailRead: .needsSetup(reason: "메일 계정 연결이 필요합니다."),
            calendarDraft: .approvalRequired,
            mapsSearch: webFetchStatus(hasGroundedSearch: false, hasLocalWebFallback: true),
            trainSearch: .needsSetup(reason: "열차 조회 연동이 아직 설정되지 않았습니다."),
            playwrightMCP: playwrightMCPStatus(.notChecked),
            browserDOM: browserDOMStatus(.notChecked),
            browserSearch: browserSearchStatus(.notChecked),
            browserClick: browserClickStatus(.notChecked),
            browserScreenshot: browserScreenshotStatus(.notChecked)
        )
    }

    private static func quoteConnectorStatus() -> ConnectorStatus {
        let hasQuoteLookupTool = AgentToolRegistry.shared.tools["finance_quote"] != nil
        return hasQuoteLookupTool
            ? .available
            : .needsSetup(reason: "시세 조회 커넥터가 설정되지 않았습니다.")
    }

    private static func newsSearchStatus(hasGroundedSearch: Bool, hasLocalWebFallback: Bool) -> ConnectorStatus {
        if hasGroundedSearch {
            return .available
        }
        return hasLocalWebFallback
            ? .degraded(reason: "뉴스 검색은 로컬 웹 폴백으로만 동작해 최신성 검증이 약합니다.")
            : .needsSetup(reason: "뉴스 검색용 웹 커넥터가 설정되지 않았습니다.")
    }

    private static func disclosureSearchStatus(hasGroundedSearch: Bool, hasLocalWebFallback: Bool) -> ConnectorStatus {
        if hasGroundedSearch {
            return .degraded(reason: "DART/KIND 전용 커넥터가 없어 웹 검색으로 공시 출처를 확인합니다.")
        }
        return hasLocalWebFallback
            ? .degraded(reason: "공시는 DART/KIND 전용 커넥터가 없어 로컬 웹 폴백으로만 동작합니다.")
            : .needsSetup(reason: "DART/KIND 공시 커넥터가 설정되지 않았습니다.")
    }

    private static func webFetchStatus(hasGroundedSearch: Bool, hasLocalWebFallback: Bool) -> ConnectorStatus {
        if hasGroundedSearch {
            return .available
        }
        return hasLocalWebFallback
            ? .degraded(reason: "웹 조회는 로컬 폴백으로만 동작합니다.")
            : .needsSetup(reason: "웹 조회 커넥터가 설정되지 않았습니다.")
    }

    private static func playwrightMCPStatus(_ health: PlaywrightMCPHealth) -> ConnectorStatus {
        if health.mcpLaunchable && health.initialized {
            return .available
        }
        if !health.nodeAvailable {
            return .needsSetup(reason: health.lastError ?? "Node.js가 필요합니다.")
        }
        if !health.npxAvailable {
            return .needsSetup(reason: health.lastError ?? "npx 실행 환경이 필요합니다.")
        }
        if !health.mcpLaunchable {
            return .needsSetup(reason: health.lastError ?? "@playwright/mcp 실행 확인이 필요합니다.")
        }
        return .unavailable(reason: health.lastError ?? "Playwright MCP initialize에 실패했습니다.")
    }

    private static func browserDOMStatus(_ health: PlaywrightMCPHealth) -> ConnectorStatus {
        health.isDOMOperational
            ? .available
            : .needsSetup(reason: health.lastError ?? "Playwright MCP snapshot tool을 확인하지 못했습니다.")
    }

    private static func browserSearchStatus(_ health: PlaywrightMCPHealth) -> ConnectorStatus {
        health.isSearchOperational
            ? .available
            : .needsSetup(reason: health.lastError ?? "Playwright MCP navigate/snapshot tool이 필요합니다.")
    }

    private static func browserClickStatus(_ health: PlaywrightMCPHealth) -> ConnectorStatus {
        health.isDOMOperational && health.clickCapable
            ? .available
            : .needsSetup(reason: health.lastError ?? "Playwright MCP click tool을 확인하지 못했습니다.")
    }

    private static func browserScreenshotStatus(_ health: PlaywrightMCPHealth) -> ConnectorStatus {
        health.mcpLaunchable && health.initialized && health.screenshotCapable
            ? .available
            : .needsSetup(reason: health.lastError ?? "Playwright MCP screenshot tool을 확인하지 못했습니다.")
    }

    private static func hasGroundedSearchProvider() -> Bool {
        let hasGemini = SecureCredentialStore.shared.hasKey(for: .gemini)
        let hasOpenAI = SecureCredentialStore.shared.hasKey(for: .openAI)
        return hasGemini || hasOpenAI
    }

    private static func hasLocalWebFallback() -> Bool {
        AgentToolRegistry.shared.tools["web_search"] != nil
    }

    func refresh() {
        lastHealth = currentHealth()
        Task { @MainActor in
            PlaywrightMCPManager.shared.refreshHealth()
        }
    }

    @MainActor
    func refreshWithBrowserHealth(_ browserHealth: PlaywrightMCPHealth) {
        lastHealth = currentHealth(browserHealth: browserHealth)
    }

    func currentHealth() -> ConnectorHealth {
        currentHealth(browserHealth: PlaywrightMCPManager.shared.health)
    }

    func currentHealth(browserHealth: PlaywrightMCPHealth) -> ConnectorHealth {
        let hasGroundedSearch = Self.hasGroundedSearchProvider()
        let hasLocalWebFallback = Self.hasLocalWebFallback()

        return ConnectorHealth(
            stockQuote: Self.quoteConnectorStatus(),
            newsSearch: Self.newsSearchStatus(hasGroundedSearch: hasGroundedSearch, hasLocalWebFallback: hasLocalWebFallback),
            disclosureSearch: Self.disclosureSearchStatus(hasGroundedSearch: hasGroundedSearch, hasLocalWebFallback: hasLocalWebFallback),
            webFetch: Self.webFetchStatus(hasGroundedSearch: hasGroundedSearch, hasLocalWebFallback: hasLocalWebFallback),
            pdfText: .available,
            imageOCR: ConnectorHealth.imageOCRUnavailable,
            mailRead: .needsSetup(reason: "Gmail 또는 Mail 읽기 연결이 필요합니다."),
            calendarDraft: .approvalRequired,
            mapsSearch: Self.webFetchStatus(hasGroundedSearch: hasGroundedSearch, hasLocalWebFallback: hasLocalWebFallback),
            trainSearch: browserHealth.isSearchOperational
                ? .degraded(reason: "열차 조회는 Playwright 브라우저 검색으로만 동작합니다.")
                : .needsSetup(reason: "열차 조회 API 또는 공식 검색 연결이 필요합니다."),
            playwrightMCP: Self.playwrightMCPStatus(browserHealth),
            browserDOM: Self.browserDOMStatus(browserHealth),
            browserSearch: Self.browserSearchStatus(browserHealth),
            browserClick: Self.browserClickStatus(browserHealth),
            browserScreenshot: Self.browserScreenshotStatus(browserHealth)
        )
    }
}
