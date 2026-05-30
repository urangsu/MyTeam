import Foundation

enum PlaywrightMCPToolName: String, Codable, Sendable {
    case navigate = "browser_navigate"
    case snapshot = "browser_snapshot"
    case click = "browser_click"
    case type = "browser_type"
    case fill = "browser_fill"
    case pressKey = "browser_press_key"
    case screenshot = "browser_take_screenshot"
    case evaluate = "browser_evaluate"
}

struct PlaywrightMCPToolCall: Codable, Sendable {
    let name: String
    let arguments: [String: String]
}

struct PlaywrightMCPToolCallResult: Codable, Sendable {
    let ok: Bool
    let text: String
    let error: String?
}

