import Foundation

// MARK: - AICallType

enum AICallType: String {
    case intentClassify  = "intent_classify"
    case workflowPlan    = "workflow_plan"
    case workflowRepair  = "workflow_repair"
    case chitchat        = "chitchat"
    case selector        = "selector"
    case tts             = "tts"
    case privacyTermsGen = "privacy_terms_gen"
}

// MARK: - AICallBudgetManager
// 세션(사용자 요청 1건) 단위로 LLM 호출 횟수를 추적하고
// 정책을 초과한 호출을 차단한다.
// + Rolling window: 전체 LLM 호출 1분당 5회 초과 시 차단 (TTS 제외)

final class AICallBudgetManager {
    static let shared = AICallBudgetManager()
    private init() {}

    // MARK: - 세션 카운터
    private var counts: [AICallType: Int] = [:]
    private var sessionID: String = ""

    // MARK: - 정책 (요청당 최대 허용 횟수)
    private let limits: [AICallType: Int] = [
        .intentClassify:  1,   // 파일 생성 요청에서는 0 (dispatch에서 스킵됨)
        .workflowPlan:    1,
        .workflowRepair:  1,
        .chitchat:        2,
        .selector:        3,
        .tts:             .max,  // TTS는 횟수 제한 없음
        .privacyTermsGen: 1      // 개인정보처리방침·약관 생성은 요청당 1회
    ]

    // MARK: - Rolling window (전체 LLM 호출량 분당 제한)
    private var rollingCallLog: [Date] = []
    private let rollingWindowSeconds: TimeInterval = 60
    private let rollingWindowLimit: Int = 5  // 1분당 최대 5회 (TTS 제외)

    /// 마지막 차단이 rolling limit 때문이었는지 여부 (blockedMessage 분기용)
    private var lastBlockWasRolling = false

    // MARK: - 세션 리셋 (새 사용자 요청마다 호출)
    // ⚠️ rollingCallLog는 여기서 절대 초기화하지 않는다.
    //    세션이 새로 시작돼도 60초 rolling window는 앱 전체 기준으로 유지돼야 한다.
    //    초기화하면 사용자가 연속 요청할 때마다 카운터가 리셋되어 rate limit이 무력화된다.

    func beginSession(id: String = UUID().uuidString) {
        sessionID = id
        counts = [:]
        // rollingCallLog — 초기화 금지 (rolling window는 세션 경계와 독립)
        AppLog.info("[Budget] 세션 시작: \(id)")
    }

    // MARK: - Rolling window 체크

    /// true = rolling budget 내, false = 1분당 한도 초과
    /// rollingCallLog prune은 여기서만 수행한다.
    private func checkRollingLimit(for type: AICallType) -> Bool {
        guard type != .tts else { return true }  // TTS는 rolling 제외
        let now = Date()
        // 오래된 항목 prune (60초 초과)
        rollingCallLog = rollingCallLog.filter { now.timeIntervalSince($0) < rollingWindowSeconds }
        if rollingCallLog.count >= rollingWindowLimit {
            lastBlockWasRolling = true
            AppLog.warning("[Budget] 🚫 Rolling limit 초과 (\(rollingCallLog.count)/\(rollingWindowLimit) in last \(Int(rollingWindowSeconds))s)")
            return false
        }
        // 허용 — 기록 추가, 플래그 초기화
        lastBlockWasRolling = false
        rollingCallLog.append(now)
        return true
    }

    // MARK: - 호출 허가 요청

    /// true = 호출 허용, false = 예산 초과로 차단 (세션 한도 또는 rolling 한도)
    @discardableResult
    func requestCall(_ type: AICallType) -> Bool {
        // 매 호출마다 플래그 초기화 — 세션 한도 차단 메시지가 rolling 메시지로 오염되지 않게
        lastBlockWasRolling = false

        // 1) Rolling window 체크 먼저 (전역 속도 제한 — 세션 경계와 무관)
        // checkRollingLimit이 false 반환 시 lastBlockWasRolling = true로 설정됨
        guard checkRollingLimit(for: type) else { return false }

        // 2) 세션 내 호출 횟수 체크 (여기까지 왔으면 rolling은 통과 — lastBlockWasRolling = false)
        let current = counts[type, default: 0]
        let limit   = limits[type, default: 1]

        if current >= limit {
            AppLog.warning("[Budget] 🚫 \(type.rawValue) 세션 한도 초과 (사용: \(current)/\(limit))")
            return false
        }
        counts[type] = current + 1
        AppLog.info("[Budget] ✅ \(type.rawValue) (\(current + 1)/\(limit))")
        return true
    }

    /// 차단 시 표시할 사용자 메시지
    func blockedMessage(for type: AICallType) -> String {
        if lastBlockWasRolling {
            return "⚠️ 요청이 너무 빠릅니다. \(Int(rollingWindowSeconds))초 후 다시 시도해 주세요."
        }
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
        case .privacyTermsGen:
            return "⚠️ 개인정보처리방침·약관 생성 요청이 너무 자주 발생했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - 현재 사용량 조회

    func usageDescription() -> String {
        let now = Date()
        let rollingCount = rollingCallLog.filter { now.timeIntervalSince($0) < rollingWindowSeconds }.count
        let sessionLines = AICallType.allCases.compactMap { type -> String? in
            guard let count = counts[type], count > 0 else { return nil }
            let limit = limits[type, default: 1]
            return "\(type.rawValue): \(count)/\(limit == .max ? "∞" : "\(limit)")"
        }
        let sessionDesc = sessionLines.isEmpty ? "0 calls" : sessionLines.joined(separator: ", ")
        return "\(sessionDesc) | rolling: \(rollingCount)/\(rollingWindowLimit)"
    }
}

extension AICallType: CaseIterable {}
