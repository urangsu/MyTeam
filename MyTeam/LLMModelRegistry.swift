import Foundation

// MARK: - KnownBrokenModel
// Round 269A-MODEL-TRUTH-GATE: 정적 blocklist 대신 "알려진 불량 모델" 추적 구조.
//
// 정책:
//   - 정적 blocklist 금지 — 미래 공식 모델 이름을 미리 차단하면 안 됨
//   - 실제로 endpoint 호출이 실패했거나 존재하지 않는 것이 확인된 ID만 여기에 기록
//   - expiresAt을 반드시 설정 — 영구 차단은 원칙적으로 금지
//   - reason + provider 필수 — 진단 가능해야 함
//   - Live discovery + smoke gate가 최종 모델 결정권을 가짐

struct KnownBrokenModel: Sendable {
    let id: String
    let provider: String   // "openai" | "claude" | "gemini" | "openrouter"
    let reason: String
    let expiresAt: Date?   // nil = 수동 제거 전까지 유지 (최대한 expiresAt 설정 권장)

    var isCurrentlyBroken: Bool {
        guard let exp = expiresAt else { return true }
        return Date() < exp
    }
}

// MARK: - LLMModelRegistry
// Round 269A-MODEL-TRUTH-GATE
//
// 목적: provider별 floor fallback 모델 ID 관리.
//       이 값은 discovery가 완전히 실패했을 때 마지막 안전망으로만 사용한다.
//       실제 사용 모델은 dynamic discovery + smoke cache가 결정한다.
//
// 업데이트 방법:
//   1. provider 공식 모델 목록 페이지에서 신규 stable ID 확인
//   2. primary / fallback 업데이트
//   3. preflight_round269_model_truth_gate.sh 실행 → 통과 확인
//   4. live_llm_smoke.sh로 실제 호출 검증 (env key 필요)

enum LLMModelRegistry {

    // MARK: - OpenAI

    enum OpenAI {
        /// Floor fallback: discovery 실패 시 최후 안전망
        static let primary:  String = "gpt-4.1"
        static let fallback: String = "gpt-4o"
        static let extended: String = "gpt-4.1-mini"

        /// 사용자 설정값 우선, 없으면 primary
        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }
    }

    // MARK: - Claude

    enum Claude {
        /// Floor fallback
        static let primary:     String = "claude-sonnet-4-5-20250514"
        static let fallback:    String = "claude-haiku-4-5-20250514"
        static let toolPrimary: String = "claude-sonnet-4-5-20250514"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }
    }

    // MARK: - Gemini

    enum Gemini {
        /// Floor fallback
        static let primary:  String = "gemini-2.5-flash"
        static let fallback: String = "gemini-2.5-flash-lite-preview-06-17"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }
    }

    // MARK: - OpenRouter

    enum OpenRouter {
        /// Floor fallback
        static let primary:  String = "anthropic/claude-sonnet-4-5"
        static let fallback: String = "openai/gpt-4.1"

        static func resolve(configured: String?) -> String {
            let t = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? primary : t
        }
    }

    // MARK: - Known Broken Models

    /// 현재 알려진 불량 모델 목록.
    /// 초기값은 비어 있음 — provider API discovery + smoke gate가 결정한다.
    /// 특정 endpoint 호출이 반복 실패하면 런타임에 등록하거나 여기에 추가할 수 있다.
    static let knownBrokenModels: [KnownBrokenModel] = [
        // 예시 (비활성):
        // KnownBrokenModel(
        //   id: "gpt-hypothetical-broken",
        //   provider: "openai",
        //   reason: "404 on /v1/chat/completions, confirmed 2026-05",
        //   expiresAt: Calendar.current.date(byAdding: .month, value: 3, to: Date())
        // )
    ]

    /// 현재 차단 상태인 모델 ID 목록
    static var knownBrokenIDs: [String] {
        knownBrokenModels.filter(\.isCurrentlyBroken).map(\.id)
    }

    /// 주어진 모델 ID가 현재 알려진 불량 모델인지 확인
    static func isKnownBroken(_ modelID: String) -> Bool {
        knownBrokenModels.contains { $0.id == modelID && $0.isCurrentlyBroken }
    }

    // MARK: - Model Family Display

    static var defaultModelFamilyLabel: String { "gpt-4.1 / claude-sonnet-4-5 / gemini-2.5-flash" }
}
