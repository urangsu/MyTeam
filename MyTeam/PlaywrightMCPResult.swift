import Foundation

struct PlaywrightMCPHealth: Codable, Sendable, Equatable {
    let nodeAvailable: Bool
    let npxAvailable: Bool
    let mcpLaunchable: Bool
    let initialized: Bool
    let snapshotCapable: Bool
    let navigateCapable: Bool
    let clickCapable: Bool
    let screenshotCapable: Bool
    let toolNames: [String]
    let checkedAt: Date
    let lastError: String?
    let version: String?

    static let notChecked = PlaywrightMCPHealth(
        nodeAvailable: false,
        npxAvailable: false,
        mcpLaunchable: false,
        initialized: false,
        snapshotCapable: false,
        navigateCapable: false,
        clickCapable: false,
        screenshotCapable: false,
        toolNames: [],
        checkedAt: .distantPast,
        lastError: "Playwright MCP 상태를 아직 확인하지 않았습니다.",
        version: nil
    )

    var isDOMOperational: Bool {
        mcpLaunchable && initialized && snapshotCapable
    }

    var isSearchOperational: Bool {
        isDOMOperational && navigateCapable
    }
}

enum BrowserEvidenceStatus: String, Codable, Sendable {
    case succeeded
    case partial
    case unavailable
    case denied
    case failed
}

enum BrowserSearchProvider: String, Codable, Sendable {
    case naverFinance
    case naverNews
    case dart
    case kind
    case naverSearch
    case google
    case korail
    case kakaoMap
    case general
}

struct BrowserEvidenceResult: Codable, Sendable, Equatable {
    let status: BrowserEvidenceStatus
    let sourceRefs: [AgentWindowManager.SourceReference]
    let snapshotID: UUID?
    let title: String?
    let url: String?
    let extractedText: String?
    let failureCode: String?

    static func unavailable(_ message: String, failureCode: String) -> BrowserEvidenceResult {
        BrowserEvidenceResult(
            status: .unavailable,
            sourceRefs: [],
            snapshotID: nil,
            title: nil,
            url: nil,
            extractedText: nil,
            failureCode: "\(failureCode): \(message)"
        )
    }
}

