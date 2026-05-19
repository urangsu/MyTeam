import Foundation

// MARK: - MemoryRetriever
// Round 244A: 현재 요청에 필요한 memory만 가져온다.
//
// 우선순위:
// 1. room memory (현재 방)
// 2. procedural memory
// 3. userProfile memory
// 4. domain memory (요청된 도메인이 있을 때만)
// 5. organization memory (현재 미지원)
//
// 금지:
// - 모든 memory를 무제한으로 반환 (maxItems 강제)
// - 다른 방의 room memory를 기본 retrieval에 포함
// - sourceText/full path 주입

enum MemoryRetriever {

    static let defaultMaxItems = 12
    static let maxRoomItems = 4
    static let maxProceduralItems = 3
    static let maxProfileItems = 3
    static let maxDomainItems = 2

    struct Input: Sendable {
        let roomID: UUID
        let agentID: String?
        let taskType: String?
        let domain: MemoryDomain?
        let userMessage: String
        let maxItems: Int

        init(
            roomID: UUID,
            agentID: String? = nil,
            taskType: String? = nil,
            domain: MemoryDomain? = nil,
            userMessage: String,
            maxItems: Int = MemoryRetriever.defaultMaxItems
        ) {
            self.roomID = roomID
            self.agentID = agentID
            self.taskType = taskType
            self.domain = domain
            self.userMessage = userMessage
            self.maxItems = maxItems
        }
    }

    // MARK: - Public API

    @MainActor
    static func retrieve(input: Input, store: MemoryStore = .shared) -> MemoryContext {
        let maxItems = max(1, min(input.maxItems, 20))  // 상한 20개
        var remaining = maxItems

        // 1. room memory (현재 방만, 다른 방 금지)
        let roomItems = store.roomMemories(for: input.roomID)
            .filter { isRelevant($0, to: input) }
            .sorted { $0.lastUsedAt ?? $0.createdAt > $1.lastUsedAt ?? $1.createdAt }
            .prefix(min(maxRoomItems, remaining))
        remaining -= roomItems.count

        // 2. procedural memory
        let proceduralItems = store.allProcedural()
            .filter { isRelevant($0, to: input) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(min(maxProceduralItems, remaining))
        remaining -= proceduralItems.count

        // 3. userProfile memory
        let profileItems = store.allUserProfile()
            .filter { isRelevant($0, to: input) }
            .sorted { $0.lastUsedAt ?? $0.createdAt > $1.lastUsedAt ?? $1.createdAt }
            .prefix(min(maxProfileItems, remaining))
        remaining -= profileItems.count

        // 4. domain memory (요청된 domain이 있을 때만)
        var domainItems: [MemoryItem] = []
        if let domain = input.domain ?? detectDomain(from: input.userMessage), remaining > 0 {
            domainItems = Array(
                store.domainItems(for: domain)
                    .filter { isRelevant($0, to: input) }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(min(maxDomainItems, remaining))
            )
        }

        return MemoryContext(
            roomMemories: Array(roomItems),
            proceduralMemories: Array(proceduralItems),
            userProfileMemories: Array(profileItems),
            domainMemories: domainItems
        )
    }

    // MARK: - Relevance Filter

    private static func isRelevant(_ item: MemoryItem, to input: Input) -> Bool {
        // 만료된 항목 제외
        if item.isExpired { return false }
        // 아직 승인 안 된 민감 항목 제외
        if item.sensitivity.requiresApproval && !item.isUserApproved { return false }
        // 다른 방 room memory 제외
        if (item.scope == .room || item.scope == .agentInRoom),
           let itemRoomID = item.roomID,
           itemRoomID != input.roomID { return false }
        return true
    }

    private static func detectDomain(from message: String) -> MemoryDomain? {
        let d = MemoryScopePolicy.detectDomain(from: message)
        return d == .general ? nil : d
    }
}
