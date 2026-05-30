import Foundation

enum BrowserActionRisk: String, Codable, Sendable {
    case allow
    case ask
    case deny
}

enum BrowserActionKind: String, Codable, Sendable {
    case navigate
    case snapshot
    case screenshot
    case searchInput
    case normalClick
    case scroll
    case select
    case tabClick
    case linkOpen
    case formFill
    case download
    case upload
    case externalAppOpen
    case geolocation
    case sessionSave
    case loginSubmit
    case passwordInput
    case cardInput
    case paymentSubmit
    case bookingConfirm
    case emailSend
    case personalIDSubmission
}

enum BrowserActionPolicy {
    static func decision(for action: BrowserActionKind, label: String = "") -> BrowserActionRisk {
        let lower = label.lowercased()
        if lower.contains("결제")
            || lower.contains("예매 확정")
            || lower.contains("예약 확정")
            || lower.contains("send")
            || lower.contains("password")
            || lower.contains("비밀번호")
            || lower.contains("카드번호") {
            return .deny
        }

        switch action {
        case .navigate, .snapshot, .screenshot, .searchInput, .normalClick, .scroll, .select, .tabClick, .linkOpen:
            return .allow
        case .formFill, .download, .upload, .externalAppOpen, .geolocation, .sessionSave, .loginSubmit:
            return .ask
        case .passwordInput, .cardInput, .paymentSubmit, .bookingConfirm, .emailSend, .personalIDSubmission:
            return .deny
        }
    }
}

