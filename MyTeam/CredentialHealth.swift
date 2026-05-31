import Foundation
import Combine

// MARK: - CredentialHealthState

enum CredentialHealthState: Equatable, Sendable {
    case connected               // 키 존재 + 마지막 테스트 성공
    case notConnected            // 키 없음
    case untested                // 키 있으나 테스트 미실행
    case testFailed(ConnectorFailureCode) // 테스트 실패
}

extension CredentialHealthState {
    var displayLabel: String {
        switch self {
        case .connected:          return "연결됨"
        case .notConnected:       return "연결 필요"
        case .untested:           return "저장됨"
        case .testFailed:         return "연결 오류"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - CredentialHealth

/// 각 provider의 자격증명 상태를 추적합니다.
struct CredentialHealth: Equatable, Sendable {
    let provider: ExternalProvider
    var state: CredentialHealthState
    var lastTestedAt: Date?
    var maskedKey: String

    init(provider: ExternalProvider) {
        self.provider = provider
        let store = SecureCredentialStore.shared
        if store.hasKey(for: provider) {
            self.state = .untested
            self.maskedKey = store.masked(provider: provider)
        } else {
            self.state = .notConnected
            self.maskedKey = "미연결"
        }
    }
}

// MARK: - CredentialHealthService

/// 모든 provider의 자격증명 상태를 관리하는 싱글톤.
@MainActor
final class CredentialHealthService: ObservableObject {
    static let shared = CredentialHealthService()

    @Published private(set) var healths: [ExternalProvider: CredentialHealth] = [:]

    private init() {
        refresh()
    }

    func refresh() {
        for provider in ExternalProvider.allCases {
            healths[provider] = CredentialHealth(provider: provider)
        }
    }

    func health(for provider: ExternalProvider) -> CredentialHealth {
        healths[provider] ?? CredentialHealth(provider: provider)
    }

    func testConnection(for provider: ExternalProvider) async {
        let result = await SecureCredentialStore.shared.testConnection(provider: provider)
        var health = self.health(for: provider)
        health.lastTestedAt = Date()
        if result.success {
            health.state = .connected
        } else {
            health.state = .testFailed(result.failureCode ?? .networkError)
        }
        health.maskedKey = SecureCredentialStore.shared.masked(provider: provider)
        healths[provider] = health
    }

    func didSaveKey(for provider: ExternalProvider) {
        var health = self.health(for: provider)
        health.state = .untested
        health.maskedKey = SecureCredentialStore.shared.masked(provider: provider)
        healths[provider] = health
    }

    func didDeleteKey(for provider: ExternalProvider) {
        var health = self.health(for: provider)
        health.state = .notConnected
        health.maskedKey = "미연결"
        health.lastTestedAt = nil
        healths[provider] = health
    }
}
