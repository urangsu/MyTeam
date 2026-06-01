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
    case appLaunchPack   = "app_launch_pack"
    case universalDocumentGen = "universal_document_gen"
    case universalDocumentRepair = "universal_document_repair"
}

// MARK: - AICallBudgetTier (Round 246A)
// 작업 모드별 호출 예산 등급. beginSession(tier:)으로 선택.
// 전면 라우터 연결은 246B/C — 246A는 인터페이스 추가 + 일부 limit 완화만.

enum AICallBudgetTier {
    case chatLight      // chitchat: 3회
    case quickTask      // 빠른 workflow: 6회
    case documentTask   // 문서 생성: 10회
    case officeReview   // 사무 검토: 12회
    case codeLite       // 코드 보조: 20회
    case deepWork       // 복합 분석: 30회
}

// MARK: - AICallBudgetSession

struct AICallBudgetSessionKey: Hashable, Sendable, CustomStringConvertible {
    let roomID: UUID?
    let workflowID: UUID?
    let requestID: String

    init(roomID: UUID? = nil, workflowID: UUID? = nil, requestID: String = UUID().uuidString) {
        self.roomID = roomID
        self.workflowID = workflowID
        self.requestID = requestID
    }

    var description: String {
        [
            roomID.map { "room=\($0.uuidString)" },
            workflowID.map { "workflow=\($0.uuidString)" },
            "request=\(requestID)"
        ].compactMap { $0 }.joined(separator: " ")
    }
}

private struct AICallBudgetSession {
    let key: AICallBudgetSessionKey
    let tier: AICallBudgetTier
    var counts: [AICallType: Int] = [:]
    let startedAt: Date = Date()
}

// MARK: - AICallBudgetManager
// 세션(사용자 요청 1건) 단위로 LLM 호출 횟수를 추적하고
// 정책을 초과한 호출을 차단한다.
// + Rolling window: 전체 LLM 호출 1분당 10회 초과 시 차단 (TTS 제외) [246A: 5→10 완화]

@MainActor
final class AICallBudgetManager {
    static let shared = AICallBudgetManager()
    private init() {}

    private enum BlockReason {
        case rolling
        case session
    }

    // MARK: - 세션 카운터
    private var sessions: [AICallBudgetSessionKey: AICallBudgetSession] = [:]
    private var activeSessionKey = AICallBudgetSessionKey(requestID: "default")
    private var lastBlockedReasonByKey: [AICallBudgetSessionKey: BlockReason] = [:]

    // MARK: - 정책 (요청당 최대 허용 횟수) [246A: chitchat 2→3 완화]
    private let baseLimits: [AICallType: Int] = [
        .intentClassify:  1,   // 파일 생성 요청에서는 0 (dispatch에서 스킵됨)
        .workflowPlan:    1,
        .workflowRepair:  1,
        .chitchat:        3,   // 246A: 2→3 완화 (directChat fallback 경로 추가로 필요량 증가)
        .selector:        3,
        .tts:             .max,  // TTS는 횟수 제한 없음
        .privacyTermsGen: 1,
        .appLaunchPack:   1,
        .universalDocumentGen: 1,
        .universalDocumentRepair: 1
    ]

    private func limits(for tier: AICallBudgetTier) -> [AICallType: Int] {
        var result = baseLimits
        switch tier {
        case .chatLight:
            result[.chitchat] = 2
            result[.selector] = 2
        case .quickTask:
            result[.workflowPlan] = 2
            result[.workflowRepair] = 1
            result[.universalDocumentGen] = 2
            result[.universalDocumentRepair] = 1
        case .documentTask:
            result[.workflowPlan] = 3
            result[.workflowRepair] = 2
            result[.universalDocumentGen] = 3
            result[.universalDocumentRepair] = 2
            result[.privacyTermsGen] = 2
            result[.appLaunchPack] = 2
        case .officeReview:
            result[.workflowPlan] = 3
            result[.workflowRepair] = 2
            result[.universalDocumentGen] = 4
            result[.universalDocumentRepair] = 2
        case .codeLite:
            result[.workflowPlan] = 4
            result[.workflowRepair] = 3
            result[.universalDocumentGen] = 6
            result[.universalDocumentRepair] = 3
            result[.selector] = 4
        case .deepWork:
            result[.workflowPlan] = 5
            result[.workflowRepair] = 4
            result[.universalDocumentGen] = 8
            result[.universalDocumentRepair] = 4
            result[.privacyTermsGen] = 3
            result[.appLaunchPack] = 3
            result[.selector] = 5
            result[.chitchat] = 4
        }
        return result
    }

    // MARK: - Rolling window (전체 LLM 호출량 분당 제한)
    private var rollingCallLog: [Date] = []
    private let rollingWindowSeconds: TimeInterval = 60
    private let rollingWindowLimit: Int = 15  // 246A: 5→10, Round 278 2-C: 10→15 완화
                                              // 사유: 사무 검토 1건이 5~7회, 사용자가 "다시" 1~2번이면 10회 도달.
                                              // 15회면 두 번까지 자연스럽게 허용.

    /// 마지막 차단이 rolling limit 때문이었는지 여부 (blockedMessage 분기용)
    private var lastBlockWasRolling = false

    // MARK: - 세션 리셋 (새 사용자 요청마다 호출)
    // ⚠️ rollingCallLog는 여기서 절대 초기화하지 않는다.
    //    세션이 새로 시작돼도 60초 rolling window는 앱 전체 기준으로 유지돼야 한다.
    //    초기화하면 사용자가 연속 요청할 때마다 카운터가 리셋되어 rate limit이 무력화된다.

    func beginSession(id: String = UUID().uuidString) {
        beginSession(key: AICallBudgetSessionKey(requestID: id), tier: .chatLight)
    }

    // Round 246A: tier 파라미터 추가. 라우터 전면 연결은 246B/C.
    func beginSession(id: String = UUID().uuidString, tier: AICallBudgetTier) {
        beginSession(key: AICallBudgetSessionKey(requestID: id), tier: tier)
    }

    func beginSession(
        roomID: UUID?,
        workflowID: UUID? = nil,
        requestID: String = UUID().uuidString,
        tier: AICallBudgetTier
    ) {
        beginSession(
            key: AICallBudgetSessionKey(roomID: roomID, workflowID: workflowID, requestID: requestID),
            tier: tier
        )
    }

    func beginSession(key: AICallBudgetSessionKey, tier: AICallBudgetTier) {
        activeSessionKey = key
        sessions[key] = AICallBudgetSession(key: key, tier: tier)
        // rollingCallLog — 초기화 금지 (rolling window는 세션 경계와 독립)
        AppLog.info("[Budget] 세션 시작: \(key.description) tier=\(tier)")
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
        requestCall(type, key: activeSessionKey)
    }

    @discardableResult
    func requestCall(_ type: AICallType, key: AICallBudgetSessionKey) -> Bool {
        // 매 호출마다 플래그 초기화 — 세션 한도 차단 메시지가 rolling 메시지로 오염되지 않게
        lastBlockWasRolling = false
        lastBlockedReasonByKey[key] = nil

        // 1) Rolling window 체크 먼저 (전역 속도 제한 — 세션 경계와 무관)
        // checkRollingLimit이 false 반환 시 lastBlockWasRolling = true로 설정됨
        guard checkRollingLimit(for: type) else {
            lastBlockedReasonByKey[key] = .rolling
            return false
        }

        // 2) 세션 내 호출 횟수 체크 (여기까지 왔으면 rolling은 통과 — lastBlockWasRolling = false)
        if sessions[key] == nil {
            sessions[key] = AICallBudgetSession(key: key, tier: .chatLight)
            activeSessionKey = key
            AppLog.warning("[Budget] 누락된 세션 자동 생성: \(key.description)")
        }

        guard var session = sessions[key] else { return false }
        let limits = limits(for: session.tier)
        let current = session.counts[type, default: 0]
        let limit   = limits[type, default: 1]

        if current >= limit {
            AppLog.warning("[Budget] 🚫 \(type.rawValue) 세션 한도 초과 key=\(key.description) (사용: \(current)/\(limit))")
            lastBlockedReasonByKey[key] = .session
            return false
        }
        session.counts[type] = current + 1
        sessions[key] = session
        activeSessionKey = key
        AppLog.info("[Budget] ✅ \(type.rawValue) key=\(key.description) (\(current + 1)/\(limit))")
        return true
    }

    /// 차단 시 표시할 사용자 메시지
    func blockedMessage(for type: AICallType) -> String {
        blockedMessage(for: type, key: activeSessionKey)
    }

    func blockedMessage(for type: AICallType, key: AICallBudgetSessionKey) -> String {
        if lastBlockedReasonByKey[key] == .rolling {
            // Round 278 2-C: 정확한 남은 쿨다운(가장 오래된 호출이 윈도우를 벗어나기까지)을 표시.
            let now = Date()
            let oldest = rollingCallLog.min() ?? now
            let elapsed = now.timeIntervalSince(oldest)
            let remaining = max(1, Int(ceil(rollingWindowSeconds - elapsed)))
            return "지금 작업이 빠르게 들어오고 있어요. 진행 중인 일이 끝나면 이어서 처리할게요 (약 \(remaining)초)."
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
        case .appLaunchPack:
            return "⚠️ 앱 출시 문서 생성 요청이 너무 자주 발생했습니다. 잠시 후 다시 시도해 주세요."
        case .universalDocumentGen:
            return "⚠️ 문서 생성 요청이 너무 자주 발생했습니다. 잠시 후 다시 시도해 주세요."
        case .universalDocumentRepair:
            return "⚠️ 문서 재생성 요청이 너무 자주 발생했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - 현재 사용량 조회

    func usageDescription() -> String {
        let now = Date()
        let rollingCount = rollingCallLog.filter { now.timeIntervalSince($0) < rollingWindowSeconds }.count
        guard let activeSession = sessions[activeSessionKey] else {
            return "0 calls | rolling: \(rollingCount)/\(rollingWindowLimit)"
        }
        let limits = limits(for: activeSession.tier)
        let sessionLines = AICallType.allCases.compactMap { type -> String? in
            guard let count = activeSession.counts[type], count > 0 else { return nil }
            let limit = limits[type, default: 1]
            return "\(type.rawValue): \(count)/\(limit == .max ? "∞" : "\(limit)")"
        }
        let sessionDesc = sessionLines.isEmpty ? "0 calls" : sessionLines.joined(separator: ", ")
        return "\(sessionDesc) | sessions: \(sessions.count) | rolling: \(rollingCount)/\(rollingWindowLimit)"
    }
}

extension AICallType: CaseIterable {}
