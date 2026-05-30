import Combine
import Foundation

@MainActor
final class PlaywrightMCPManager: ObservableObject {
    static let shared = PlaywrightMCPManager()

    @Published private(set) var health: PlaywrightMCPHealth = .notChecked
    @Published private(set) var isRefreshing = false

    private init() {}

    func refreshHealth() {
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
