import Foundation
import Combine
import CryptoKit

enum LLMReadinessStage: String, Codable, Equatable, Sendable {
    case notStored
    case stored
    case authenticated
    case modelAccessible
    case smokeTesting
    case ready
}

enum LLMReadinessFailure: String, Codable, Equatable, Sendable {
    case invalidCredential
    case modelNotAccessible
    case endpointUnsupported
    case quotaExceeded
    case rateLimited
    case timeout
    case networkUnavailable
    case malformedResponse
    case emptyGeneration
    case cancelled
    case providerError

    var connectorFailureCode: ConnectorFailureCode {
        switch self {
        case .invalidCredential:
            return .invalidAPIKey
        case .modelNotAccessible:
            return .permissionDenied
        case .quotaExceeded, .rateLimited:
            return .rateLimited
        case .timeout, .networkUnavailable, .cancelled:
            return .networkError
        case .endpointUnsupported, .malformedResponse, .emptyGeneration:
            return .responseParseFailed
        case .providerError:
            return .providerUnavailable
        }
    }
}

struct LLMReadinessEvidence: Codable, Equatable, Sendable {
    let provider: ExternalProvider
    let stage: LLMReadinessStage
    let modelID: String
    let endpoint: String
    let keyFingerprint: String
    let validatedAt: Date
    let cached: Bool
}

struct LLMReadinessError: LocalizedError, Sendable {
    let reason: LLMReadinessFailure
    let message: String

    var errorDescription: String? { message }
}

actor LLMReadinessCache {
    static let shared = LLMReadinessCache()

    private static let storageKey = "MyTeam.LLMReadinessCache.v1"
    private static let maxAge: TimeInterval = 24 * 60 * 60
    private var entries: [LLMReadinessEvidence]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([LLMReadinessEvidence].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    nonisolated static func keyFingerprint(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    func evidence(
        provider: ExternalProvider,
        key: String,
        modelID: String,
        endpoint: String
    ) -> LLMReadinessEvidence? {
        let fingerprint = Self.keyFingerprint(for: key)
        let now = Date()
        entries.removeAll { now.timeIntervalSince($0.validatedAt) > Self.maxAge }
        guard let evidence = entries.first(where: {
            $0.provider == provider &&
            $0.keyFingerprint == fingerprint &&
            $0.modelID == modelID &&
            $0.endpoint == endpoint &&
            $0.stage == .ready
        }) else {
            persist()
            return nil
        }
        persist()
        return LLMReadinessEvidence(
            provider: evidence.provider,
            stage: evidence.stage,
            modelID: evidence.modelID,
            endpoint: evidence.endpoint,
            keyFingerprint: evidence.keyFingerprint,
            validatedAt: evidence.validatedAt,
            cached: true
        )
    }

    func store(_ evidence: LLMReadinessEvidence) {
        entries.removeAll { entry in
            entry.provider == evidence.provider &&
            entry.keyFingerprint == evidence.keyFingerprint &&
            entry.modelID == evidence.modelID &&
            entry.endpoint == evidence.endpoint
        }
        entries.append(evidence)
        persist()
    }

    func invalidate(provider: ExternalProvider) {
        entries.removeAll { $0.provider == provider }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - CredentialHealthState

enum CredentialHealthState: Equatable, Sendable {
    case connected               // 정확한 선택 모델 또는 실제 provider endpoint 검증 성공
    case notConnected            // 키 없음
    case untested                // 키 있으나 테스트 미실행
    case testUnavailable         // 키는 있으나 이 provider의 실제 검증 미구현
    case testFailed(ConnectorFailureCode) // 테스트 실패
}

extension CredentialHealthState {
    var displayLabel: String {
        switch self {
        case .connected:          return "사용 가능"
        case .notConnected:       return "연결 안 됨"
        case .untested:           return "키 저장됨"
        case .testUnavailable:    return "저장됨, 자동 확인 미지원"
        case .testFailed:         return "확인 필요"
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
    var llmReadiness: LLMReadinessEvidence?

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
        self.llmReadiness = nil
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

    func testConnection(for provider: ExternalProvider, force: Bool = false) async {
        let result = await SecureCredentialStore.shared.testConnection(provider: provider, force: force)
        var health = self.health(for: provider)
        health.lastTestedAt = Date()
        health.llmReadiness = result.llmReadiness
        if result.success {
            health.state = .connected
        } else if result.failureCode == .providerUnavailable {
            health.state = .testUnavailable
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
        health.llmReadiness = nil
        healths[provider] = health
        Task { await LLMReadinessCache.shared.invalidate(provider: provider) }
    }

    func didDeleteKey(for provider: ExternalProvider) {
        var health = self.health(for: provider)
        health.state = .notConnected
        health.maskedKey = "미연결"
        health.lastTestedAt = nil
        health.llmReadiness = nil
        healths[provider] = health
        Task { await LLMReadinessCache.shared.invalidate(provider: provider) }
    }
}
