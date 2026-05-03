import Foundation
import Combine

// MARK: - LLMCapability

/// LLM 라우팅 시 요청되는 기능 카테고리
enum LLMCapability {
    case webSearch      // /search, 뉴스, 최신 정보
    case toolUse        // Claude tool_use 루프
    case longContext    // 긴 문서 요약, 대용량 첨부파일
    case vision         // 이미지 분석
}

// MARK: - LLMProviderConfig

/// provider별 런타임 설정 스냅샷 (모델 ID + discovery 캐시 포함)
struct LLMProviderConfig: Codable {
    let provider: LLMProvider
    var selectedModelId: String?        // nil = auto-discover
    var supportsToolUse: Bool           // 현재 선택 모델이 tool_use 지원 여부
    var supportsWebSearch: Bool         // 웹 검색 기능 (Gemini Grounding, OpenAI web_search)
    var discoveredModels: [String]      // 최근 discovery 목록
    var lastDiscoveryDate: Date?        // TTL 체크 기준점
}

// MARK: - LLMConfigCatalog

/// 모든 LLM provider 설정을 단일 진입점으로 관리.
/// - 모델 discovery 결과를 UserDefaults에 캐시 (TTL: 1시간)
/// - tool 실행 시 가장 적합한 provider를 라우팅
@MainActor
final class LLMConfigCatalog: ObservableObject {

    static let shared = LLMConfigCatalog()

    @Published private(set) var configs: [LLMProvider: LLMProviderConfig] = [:]

    private let cacheTTL: TimeInterval = 3600  // 1시간
    private let udKey = "MyTeam.LLMConfigCatalog"

    private init() { load() }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: udKey),
           let decoded = try? JSONDecoder().decode([String: LLMProviderConfig].self, from: data) {
            configs = Dictionary(uniqueKeysWithValues: decoded.compactMap { k, v in
                LLMProvider(rawValue: k).map { ($0, v) }
            })
        }
        // 존재하지 않는 provider는 기본값으로 초기화
        for provider in LLMProvider.allCases where configs[provider] == nil {
            configs[provider] = defaultConfig(for: provider)
        }
    }

    private func save() {
        let encoded = Dictionary(uniqueKeysWithValues: configs.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    private func defaultConfig(for provider: LLMProvider) -> LLMProviderConfig {
        switch provider {
        case .gemini:
            return LLMProviderConfig(provider: .gemini, selectedModelId: nil,
                                     supportsToolUse: false, supportsWebSearch: true,
                                     discoveredModels: [], lastDiscoveryDate: nil)
        case .openAI:
            return LLMProviderConfig(provider: .openAI, selectedModelId: nil,
                                     supportsToolUse: true, supportsWebSearch: true,
                                     discoveredModels: [], lastDiscoveryDate: nil)
        case .claude:
            return LLMProviderConfig(provider: .claude, selectedModelId: nil,
                                     supportsToolUse: true, supportsWebSearch: false,
                                     discoveredModels: [], lastDiscoveryDate: nil)
        case .openRouter:
            return LLMProviderConfig(provider: .openRouter, selectedModelId: nil,
                                     supportsToolUse: false, supportsWebSearch: false,
                                     discoveredModels: [], lastDiscoveryDate: nil)
        }
    }

    // MARK: - TTL-aware discovery

    /// TTL(1시간) 만료 시 AIService discovery를 재실행해 캐시 갱신
    func refreshIfNeeded(_ provider: LLMProvider) async {
        guard var cfg = configs[provider] else { return }
        let isExpired = cfg.lastDiscoveryDate.map { Date().timeIntervalSince($0) > cacheTTL } ?? true
        guard isExpired else { return }

        // API 키 확인
        let keychainKey: String
        switch provider {
        case .gemini:     keychainKey = "geminiAPIKey"
        case .openAI:     keychainKey = "openAIAPIKey"
        case .claude:     keychainKey = "claudeAPIKey"
        case .openRouter: keychainKey = "openRouterAPIKey"
        }
        let apiKey = KeychainManager.load(key: keychainKey) ?? ""
        guard !apiKey.isEmpty else { return }

        // AIService의 discovery 함수 호출
        do {
            let modelId = try await AIService.shared.discoverModel(for: provider, apiKey: apiKey)
            cfg.selectedModelId = modelId
            cfg.lastDiscoveryDate = Date()
            if !modelId.isEmpty && !cfg.discoveredModels.contains(modelId) {
                cfg.discoveredModels.insert(modelId, at: 0)
                if cfg.discoveredModels.count > 10 { cfg.discoveredModels.removeLast() }
            }
            configs[provider] = cfg
            save()
            AppLog.info("[LLMCatalog] \(provider.displayName) discovery 갱신: \(modelId)")
        } catch {
            AppLog.debug("[LLMCatalog] \(provider.displayName) discovery 실패: \(error)")
        }
    }

    /// 모든 provider TTL 체크 (앱 포그라운드 복귀 시 호출)
    func refreshAllIfNeeded() async {
        for provider in LLMProvider.allCases {
            await refreshIfNeeded(provider)
        }
    }

    // MARK: - Tool-capable 라우팅

    /// 요청된 capability를 가진 provider 중 API 키가 있는 최적 provider 반환.
    /// 우선순위: capability 지원 여부 → API 키 존재 여부
    func bestProvider(for capability: LLMCapability) -> LLMProvider? {
        let candidates: [LLMProvider]
        switch capability {
        case .webSearch:
            // Gemini (Grounding) > OpenAI (web_search) > 기타
            candidates = [.gemini, .openAI, .openRouter, .claude]
        case .toolUse:
            // Claude > OpenAI > OpenRouter
            candidates = [.claude, .openAI, .openRouter, .gemini]
        case .longContext:
            // Gemini (1M) > Claude (200K) > OpenAI (128K)
            candidates = [.gemini, .claude, .openAI, .openRouter]
        case .vision:
            candidates = [.gemini, .openAI, .claude, .openRouter]
        }

        // capability 지원 + API 키 있는 첫 번째 provider
        for provider in candidates {
            let cfg = configs[provider]
            let supported: Bool
            switch capability {
            case .webSearch: supported = cfg?.supportsWebSearch ?? false
            case .toolUse:   supported = cfg?.supportsToolUse ?? false
            case .longContext, .vision: supported = true  // 모든 provider가 기본 지원
            }
            guard supported else { continue }
            let keychainKey: String
            switch provider {
            case .gemini:     keychainKey = "geminiAPIKey"
            case .openAI:     keychainKey = "openAIAPIKey"
            case .claude:     keychainKey = "claudeAPIKey"
            case .openRouter: keychainKey = "openRouterAPIKey"
            }
            let hasKey = !(KeychainManager.load(key: keychainKey) ?? "").isEmpty
            if hasKey { return provider }
        }
        return nil
    }

    /// capability 기반 best provider, 없으면 현재 desk의 provider 사용
    func routeOrDefault(_ capability: LLMCapability, fallback: LLMProvider) -> LLMProvider {
        bestProvider(for: capability) ?? fallback
    }
}

// MARK: - AIService discovery 브릿지

extension AIService {
    /// provider별 최신 모델 ID를 한 번에 조회 (LLMConfigCatalog에서 호출)
    func discoverModel(for provider: LLMProvider, apiKey: String) async throws -> String {
        switch provider {
        case .gemini:     return try await discoverLatestGeminiModelPublic(apiKey: apiKey)
        case .claude:     return try await discoverLatestClaudeModelPublic(apiKey: apiKey)
        case .openAI:     return try await discoverLatestOpenAIModelPublic(apiKey: apiKey)
        case .openRouter: throw AIServiceError.invalidResponse  // OpenRouter는 수동 설정
        }
    }

    // 기존 private 함수들을 internal로 래핑
    func discoverLatestGeminiModelPublic(apiKey: String) async throws -> String {
        return try await discoverLatestGeminiModel(apiKey: apiKey)
    }
    func discoverLatestClaudeModelPublic(apiKey: String) async throws -> String {
        return try await discoverLatestClaudeModel(apiKey: apiKey)
    }
    func discoverLatestOpenAIModelPublic(apiKey: String) async throws -> String {
        return try await discoverLatestOpenAIModel(apiKey: apiKey)
    }
}
