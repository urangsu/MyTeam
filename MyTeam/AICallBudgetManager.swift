import Foundation

// MARK: - AICallType

enum AICallType: String {
    case intentClassify  = "intent_classify"
    case workflowPlan    = "workflow_plan"
    case workflowRepair  = "workflow_repair"
    case chitchat        = "chitchat"
    case selector        = "selector"
    case tts             = "tts"
}

// MARK: - AICallBudgetManager
// 세션(사용자 요청 1건) 단위로 LLM 호출 횟수를 추적하고
// 정책을 초과한 호출을 차단한다.

final class AICallBudgetManager {
    static let shared = AICallBudgetManager()
    private init() {}

    // MARK: - 세션 카운터
    private var counts: [AICallType: Int] = [:]
    private var sessionID: String = ""

    // MARK: - 정책 (요청당 최대 허용 횟수)
    private let limits: [AICallType: Int] = [
        .intentClassify: 1,   // 파일 생성 요청에서는 0 (dispatch에서 스킵됨)
        .workflowPlan:   1,
        .workflowRepair: 1,
        .chitchat:       2,
        .selector:       3,
        .tts:            .max  // TTS는 횟수 제한 없음
    ]

    // MARK: - 세션 리셋 (새 사용자 요청마다 호출)

    func beginSession(id: String = UUID().uuidString) {
        sessionID = id
        counts = [:]
        AppLog.info("[Budget] 세션 시작: \(id)")
    }

    // MARK: - 호출 허가 요청

    /// true = 호출 허용, false = 예산 초과로 차단
    @discardableResult
    func requestCall(_ type: AICallType) -> Bool {
        let current = counts[type, default: 0]
        let limit   = limits[type, default: 1]

        if current >= limit {
            AppLog.warning("[Budget] 🚫 \(type.rawValue) 예산 초과 (사용: \(current)/\(limit))")
            return false
        }
        counts[type] = current + 1
        AppLog.info("[Budget] ✅ \(type.rawValue) (\(current + 1)/\(limit))")
        return true
    }

    /// 차단 시 표시할 사용자 메시지
    func blockedMessage(for type: AICallType) -> String {
        switch type {
        case .workflowPlan, .workflowRepair:
            return "⚠️ 요청이 너무 자주 반복되어 잠시 멈췄습니다. 다시 시도해 주세요."
        case .intentClassify:
            return "⚠️ 분류 요청 한도에 도달했습니다. 잠시 후 다시 시도해 주세요."
        case .chitchat:
            return "잠시 후 다시 말씀해 주세요."
        case .selector:
            return "⚠️ 너무 많은 에이전트 선택 요청이 발생했습니다."
        case .tts:
            return ""
        }
    }

    // MARK: - 현재 사용량 조회

    func usageDescription() -> String {
        let lines = AICallType.allCases.compactMap { type -> String? in
            guard let count = counts[type], count > 0 else { return nil }
            let limit = limits[type, default: 1]
            return "\(type.rawValue): \(count)/\(limit == .max ? "∞" : "\(limit)")"
        }
        return lines.isEmpty ? "0 calls" : lines.joined(separator: ", ")
    }
}

extension AICallType: CaseIterable {}
