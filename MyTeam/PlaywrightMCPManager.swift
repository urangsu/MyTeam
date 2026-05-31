import Combine
import Foundation

@MainActor
final class PlaywrightMCPManager: ObservableObject {
    static let shared = PlaywrightMCPManager()

    @Published private(set) var health: PlaywrightMCPHealth = .notChecked
    @Published private(set) var isRefreshing = false

    private init() {}

    func refreshHealth() {
        // P0-1: App Store profile에서 Playwright MCP health check 자체를 차단
        guard AppReleaseProfile.current.policy.allowsPlaywrightMCP else {
            AppLog.info("[PlaywrightMCP] 현재 배포 프로필에서 비활성화됨 (profile: \(AppReleaseProfile.current.rawValue))")
            health = .notChecked
            isRefreshing = false
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let next = await PlaywrightMCPClient.shared.probeHealth()
            health = next
            ConnectorRegistry.shared.refreshWithBrowserHealth(next)
            isRefreshing = false
        }
    }
}
