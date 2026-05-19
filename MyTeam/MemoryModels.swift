import Foundation

// MARK: - MemoryScope
// Round 244A: 방 상태(room state)와 사용자 기억(user memory)을 분리하는 계층 구조

enum MemoryScope: String, Codable, Equatable, Sendable, CaseIterable {
    /// 현재 메시지 턴 안에서만 유효 (전달 후 폐기)
    case turn
    /// 특정 방(워크룸/개인 대화)에 묶인 기억
    case room
    /// 특정 방 + 에이전트에 묶인 기억
    case agentInRoom
    /// 사용자 개인 선호/출력 스타일/글투
    case userProfile
    /// 반복 업무 절차, 체크리스트 방식, 결과물 포맷
    case procedural
    /// 특정 도메인(회계/마케팅/법무 등) 기준 지식
    case domain
    /// 조직 공유 기준 (다음 버전 예정, 현재 저장 금지)
    case organization

    var displayName: String {
        switch self {
        case .turn:          return "현재 턴"
        case .room:          return "이 방"
        case .agentInRoom:   return "이 방의 에이전트"
        case .userProfile:   return "내 선호"
        case .procedural:    return "업무 방식"
        case .domain:        return "도메인 기준"
        case .organization:  return "조직 공유"
        }
    }

    /// 자동 저장 가능 여부 (false면 사용자 승인 필요)
    var isAutoStorable: Bool {
        switch self {
        case .turn, .room, .agentInRoom: return true
        case .userProfile, .procedural:  return true   // publicPreference/workPreference만
        case .domain:                    return false   // 검토 후 승인
        case .organization:              return false
        }
    }
}

// MARK: - MemorySensitivityClass
// 기존 MemorySensitivity (publicLow/workspace/personal/confidential/secret)와 독립된 분류
// 새 memory 시스템 전용 — MemoryRetentionPolicy와 병행 사용

enum MemorySensitivityClass: String, Codable, Equatable, Sendable {
    /// 공개 선호 (항상/출력 스타일/포맷) — 자동 저장 가능
    case publicPreference
    /// 업무 선호 (도구/방식/절차) — 자동 저장 가능
    case workPreference
    /// 사업 기밀 (거래처/금액/계약 조건) — 승인 필요
    case businessConfidential
    /// 개인 민감 (개인정보/의료/법적) — 승인 필요
    case personalSensitive
    /// 자격증명 유사 (API key/token/password 패턴) — 저장 금지
    case credentialLike

    var requiresApproval: Bool {
        switch self {
        case .publicPreference, .workPreference: return false
        case .businessConfidential, .personalSensitive: return true
        case .credentialLike: return false   // 저장 금지, 승인 경로도 없음
        }
    }

    var isStorageBlocked: Bool {
        return self == .credentialLike
    }
}

// MARK: - MemoryDomain

enum MemoryDomain: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case accounting       // 회계/세무
    case legal            // 법무/계약
    case marketing        // 마케팅/콘텐츠
    case projectManagement // 프로젝트 관리
    case development      // 개발/기술
    case appLaunch        // 앱 출시
    case general          // 일반

    var displayName: String {
        switch self {
        case .accounting:        return "회계/세무"
        case .legal:             return "법무/계약"
        case .marketing:         return "마케팅/콘텐츠"
        case .projectManagement: return "프로젝트 관리"
        case .development:       return "개발/기술"
        case .appLaunch:         return "앱 출시"
        case .general:           return "일반"
        }
    }
}

// MARK: - MemoryItem

struct MemoryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let scope: MemoryScope
    let roomID: UUID?           // room / agentInRoom scope에 필수
    let agentID: String?        // agentInRoom scope에 필수
    let domain: MemoryDomain?
    let title: String           // 30자 이내 요약
    let content: String         // 일반화된 선호/절차 (원문/파일 내용 금지)
    let sourceRoomID: UUID?     // 출처 방 ID (감사 목적)
    let sourceMessageID: UUID?  // 출처 메시지 ID
    let sourceArtifactID: String? // 출처 artifact ID
    var confidence: Double       // 0.0 ~ 1.0
    let sensitivity: MemorySensitivityClass
    let createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var isUserApproved: Bool     // 사용자가 직접 승인했는지
    var isAutoExtracted: Bool    // heuristic/LLM으로 자동 추출됐는지
    var ttlDays: Int?            // nil = 영구 보존

    init(
        id: UUID = UUID(),
        scope: MemoryScope,
        roomID: UUID? = nil,
        agentID: String? = nil,
        domain: MemoryDomain? = nil,
        title: String,
        content: String,
        sourceRoomID: UUID? = nil,
        sourceMessageID: UUID? = nil,
        sourceArtifactID: String? = nil,
        confidence: Double = 0.8,
        sensitivity: MemorySensitivityClass,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isUserApproved: Bool = false,
        isAutoExtracted: Bool = true,
        ttlDays: Int? = nil
    ) {
        self.id = id
        self.scope = scope
        self.roomID = roomID
        self.agentID = agentID
        self.domain = domain
        self.title = title
        self.content = content
        self.sourceRoomID = sourceRoomID
        self.sourceMessageID = sourceMessageID
        self.sourceArtifactID = sourceArtifactID
        self.confidence = confidence
        self.sensitivity = sensitivity
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.isUserApproved = isUserApproved
        self.isAutoExtracted = isAutoExtracted
        self.ttlDays = ttlDays
    }

    /// TTL 만료 여부
    var isExpired: Bool {
        guard let days = ttlDays else { return false }
        let expiry = createdAt.addingTimeInterval(Double(days) * 86400)
        return Date() > expiry
    }
}

// MARK: - MemoryCandidate
// consolidator가 추출한 후보 — 아직 저장 전

struct MemoryCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let suggestedScope: MemoryScope
    let suggestedSensitivity: MemorySensitivityClass
    let title: String
    let content: String
    let sourceRoomID: UUID?
    let reason: String          // 왜 이 scope를 제안하는지
    let confidence: Double
    let isStorageBlocked: Bool  // credentialLike → 항상 true

    init(
        id: UUID = UUID(),
        suggestedScope: MemoryScope,
        suggestedSensitivity: MemorySensitivityClass,
        title: String,
        content: String,
        sourceRoomID: UUID? = nil,
        reason: String,
        confidence: Double = 0.75
    ) {
        self.id = id
        self.suggestedScope = suggestedScope
        self.suggestedSensitivity = suggestedSensitivity
        self.title = title
        self.content = content
        self.sourceRoomID = sourceRoomID
        self.reason = reason
        self.confidence = confidence
        self.isStorageBlocked = suggestedSensitivity.isStorageBlocked
    }
}

// MARK: - MemoryReviewCandidate
// UX stub — 사용자에게 승인/거부를 물어볼 때 사용

struct MemoryReviewCandidate: Identifiable, Equatable, Sendable {
    enum Action: String, Sendable {
        case rememberForThisRoom
        case rememberAlways
        case doNotRemember
    }

    let id: UUID
    let candidate: MemoryCandidate
    var pendingAction: Action?

    init(id: UUID = UUID(), candidate: MemoryCandidate) {
        self.id = id
        self.candidate = candidate
    }
}

// MARK: - MemoryContext
// Retriever 출력 — prompt builder에 주입할 준비된 기억 묶음

struct MemoryContext: Equatable, Sendable {
    let roomMemories: [MemoryItem]
    let proceduralMemories: [MemoryItem]
    let userProfileMemories: [MemoryItem]
    let domainMemories: [MemoryItem]

    var isEmpty: Bool {
        roomMemories.isEmpty && proceduralMemories.isEmpty
        && userProfileMemories.isEmpty && domainMemories.isEmpty
    }

    var totalCount: Int {
        roomMemories.count + proceduralMemories.count
        + userProfileMemories.count + domainMemories.count
    }

    /// system prompt에 주입할 간략한 메모리 요약 (최대 maxChars자)
    func promptSummary(maxChars: Int = 600) -> String {
        var lines: [String] = []

        if !proceduralMemories.isEmpty {
            lines.append("【업무 방식】")
            for m in proceduralMemories.prefix(3) {
                lines.append("- \(m.content)")
            }
        }
        if !userProfileMemories.isEmpty {
            lines.append("【사용자 선호】")
            for m in userProfileMemories.prefix(3) {
                lines.append("- \(m.content)")
            }
        }
        if !roomMemories.isEmpty {
            lines.append("【이 방 컨텍스트】")
            for m in roomMemories.prefix(3) {
                lines.append("- \(m.content)")
            }
        }
        if !domainMemories.isEmpty {
            lines.append("【도메인 기준】")
            for m in domainMemories.prefix(2) {
                lines.append("- \(m.content)")
            }
        }

        let joined = lines.joined(separator: "\n")
        return joined.count > maxChars ? String(joined.prefix(maxChars)) + "…" : joined
    }

    static let empty = MemoryContext(
        roomMemories: [],
        proceduralMemories: [],
        userProfileMemories: [],
        domainMemories: []
    )
}
