import SwiftUI

// MARK: - LLM Provider (ModelRouter)
/// 에이전트별 AI 뇌(Brain) 제공자 설정
/// AIService.getResponseStream()이 이 값을 기반으로 API 엔드포인트를 동적 라우팅
enum LLMProvider: String, Codable, CaseIterable {
    case gemini      = "gemini"
    case openAI      = "openai"
    case claude      = "claude"
    case openRouter  = "openrouter"

    var displayName: String {
        switch self {
        case .gemini:     return "Gemini"
        case .openAI:     return "OpenAI"
        case .claude:     return "Claude"
        case .openRouter: return "OpenRouter"
        }
    }
}

// MARK: - AgentConfig (AgentWindowManager에서 분리)
// AgentWindowManager.AgentConfig 타입 유지 — 기존 참조 코드 변경 불필요

extension AgentWindowManager {

    struct AgentConfig: Identifiable {
        let id: String
        let name: String
        let role: String         // 예: "프로젝트 매니저" (UI 상단용)
        let emoji: String        // 평상시 이모지 (스프라이트 없을 때 폴백)
        let color: Color
        let isPremium: Bool      // 교체 창 UI용 (무료/프리미엄 표시)
        var status: String       // 현재 상태

        // ── 스프라이트 애니메이션 ──
        // Assets에 등록된 PNG 시퀀스 파일명 접두사
        // nil이면 fallbackImageName으로 폴백합니다.
        // 예: "sloth" → sloth_idle_001.png, sloth_joy_001.png ...
        let spriteName: String?

        // ── 폴백 이미지 ──
        // 스프라이트가 없을 때 표시할 캐릭터 얼굴 이미지명
        // Assets.xcassets에 등록된 이미지 파일 이름
        // 예: "치코_profile", "penguin_face"
        let fallbackImageName: String

        // ── 개인별 드래그 반응 ──
        let dragEmoji: String    // 드래그 중 이모지 (스프라이트 없을 때 폴백)
        let dragRotation: Double // 기울기 각도
        let dragSoundName: String
        let dropSoundName: String

        // ── ModelRouter: 에이전트별 AI 뇌 설정 ──
        /// 이 에이전트가 사용할 LLM 제공자 (기본값: Gemini)
        var llmProvider: LLMProvider = .gemini

        /// OpenRouter 전용 모델 ID
        /// llmProvider == .openRouter 일 때 API 요청 body에 동적 삽입
        /// 예: "meta-llama/llama-3-8b-instruct", "anthropic/claude-3-haiku"
        var openRouterModelId: String? = nil

        mutating func applyDeskRouting(index: Int) {
            let providerKey = "llmProvider_desk_\(index)"
            let modelKey = "openRouterModelId_desk_\(index)"
            if let raw = UserDefaults.standard.string(forKey: providerKey),
               let provider = LLMProvider(rawValue: raw) {
                llmProvider = provider
            } else if let raw = UserDefaults.standard.string(forKey: "defaultLLMProvider"),
                      let provider = LLMProvider(rawValue: raw) {
                llmProvider = provider
            }

            if let model = UserDefaults.standard.string(forKey: modelKey), !model.isEmpty {
                openRouterModelId = model
            } else if let model = UserDefaults.standard.string(forKey: "openRouterModelId"), !model.isEmpty {
                openRouterModelId = model
            }
        }
    }

}
