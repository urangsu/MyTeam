import Foundation

// MARK: - LLMModelRegistry
// Round 264-MODEL-REGISTRY
//
// 목적: provider별 검증된 production model ID를 한 곳에서 관리.
// AIModelPolicy.pinnedModelID는 이 registry의 wrapper다.
//
// 모델 선정 기준 (2026-05):
//   - OpenAI:     gpt-4.1 (2025-04 출시, chat API 공식 지원)
//                 fallback: gpt-4o
//   - Claude:     claude-sonnet-4-5-20250514 (비용/속도 균형, Anthropic 공식 dated ID)
//                 fallback: claude-haiku-4-5-20250514
//   - Gemini:     gemini-2.5-flash (Google Gemini 공식 production)
//                 fallback: gemini-2.5-flash-lite-preview-06-17
//   - OpenRouter: anthropic/claude-sonnet-4-5 (OpenRouter route)
//                 fallback: openai/gpt-4.1
//
// 절대 사용 금지 (검증 실패 또는 미존재):
//   gpt-5.5, gpt-5.1, gpt-5.2, claude-opus-4-7,
//   openai/gpt-5.5, gemini-2.0-flash (구버전)
//
// 업데이트 방법:
//   1. provider 공식 모델 목록 페이지에서 신규 stable ID 확인
//   2. LLMModelRegistry.primary / fallback 업데이트
//   3. preflight_round264_model_registry.sh 실행 → 통과 확인
//   4. live_llm_smoke.sh로 실제 호출 검증 (env key 필요)

enum LLMModelRegistry {

    // MARK: - OpenAI

    enum OpenAI {
        /// 기본 모델: gpt-4.1 (2025-04, chat API 공식)
        static let primary:  String = "gpt-4.1"
        /// 1차 fallback
        static let fallback: String = "gpt-4o"
        /// 대용량 컨텍스트 필요 시
        static let extended: String = "gpt-4.1-mini"

        /// 현재 user-configured 값이 유효하면 사용, 없으면 primary
        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }

        /// 사용 금지 model ID 목록 — 앱이 이 값을 포함하면 preflight 실패
        static let blockedIDs: [String] = ["gpt-5.5", "gpt-5.1", "gpt-5.2", "gpt-5"]
    }

    // MARK: - Claude

    enum Claude {
        /// 기본 모델: claude-sonnet-4-5-20250514 (Anthropic dated ID, production)
        static let primary:  String = "claude-sonnet-4-5-20250514"
        /// 1차 fallback (고속/저비용)
        static let fallback: String = "claude-haiku-4-5-20250514"
        /// Tool-calling 전용 (최고 성능)
        static let toolPrimary: String = "claude-sonnet-4-5-20250514"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }

        static let blockedIDs: [String] = ["claude-opus-4-7", "claude-opus-4-6", "claude-opus-4-8"]
    }

    // MARK: - Gemini

    enum Gemini {
        /// 기본 모델: gemini-2.5-flash (Google 공식 production)
        static let primary:  String = "gemini-2.5-flash"
        /// 1차 fallback
        static let fallback: String = "gemini-2.5-flash-lite-preview-06-17"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }

        static let blockedIDs: [String] = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
    }

    // MARK: - OpenRouter

    enum OpenRouter {
        /// 기본 라우팅: Anthropic Claude (OpenRouter route ID)
        static let primary:  String = "anthropic/claude-sonnet-4-5"
        /// 1차 fallback
        static let fallback: String = "openai/gpt-4.1"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }

        static let blockedIDs: [String] = ["openai/gpt-5.5", "openai/gpt-5", "openai/gpt-5.1"]
    }

    // MARK: - Unified Blocked List

    /// 전체 provider 금지 ID 목록 합집합
    static let allBlockedIDs: [String] = OpenAI.blockedIDs + Claude.blockedIDs + Gemini.blockedIDs + OpenRouter.blockedIDs

    /// 주어진 모델 ID가 금지 목록에 있는지 확인
    static func isBlocked(_ modelID: String) -> Bool {
        allBlockedIDs.contains(modelID)
    }

    // MARK: - Model Family Display

    static var defaultModelFamilyLabel: String { "gpt-4.1 / claude-sonnet-4-5 / gemini-2.5-flash" }
}
