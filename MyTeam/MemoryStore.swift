import Foundation
import Combine

// MARK: - MemoryStore
// Round 244A: 방별/사용자/절차/도메인 기억을 분리 저장하는 중앙 저장소.
// roomID 없는 room memory, credentialLike 저장은 하드 블록.

@MainActor
final class MemoryStore: ObservableObject {

    static let shared = MemoryStore()
    private init() { load() }

    // ── 저장소 ──────────────────────────────────────────────────────
    /// 방별 메모리 (scope == .room 또는 .agentInRoom)
    @Published private(set) var memoriesByRoom: [UUID: [MemoryItem]] = [:]
    /// 사용자 전역 선호 (scope == .userProfile)
    @Published private(set) var userProfileMemories: [MemoryItem] = []
    /// 반복 업무 절차 (scope == .procedural)
    @Published private(set) var proceduralMemories: [MemoryItem] = []
    /// 도메인별 기준 지식 (scope == .domain)
    @Published private(set) var domainMemories: [MemoryDomain: [MemoryItem]] = [:]

    // ── 사용자 검토 대기 후보 ────────────────────────────────────────
    @Published var pendingReviewCandidates: [MemoryReviewCandidate] = []

    // MARK: - Add

    /// 메모리 저장. credentialLike는 하드 블록, room scope는 roomID 필수.
    @discardableResult
    func add(_ item: MemoryItem) -> Bool {
        // 저장 금지: credentialLike
        guard !item.sensitivity.isStorageBlocked else {
            AppLog.info("[MemoryStore] blocked credentialLike memory: \(item.title)")
            return false
        }
        // room scope: roomID 필수
        if (item.scope == .room || item.scope == .agentInRoom) && item.roomID == nil {
            AppLog.info("[MemoryStore] blocked room-scope memory without roomID: \(item.title)")
            return false
        }
        // organization scope: 현재 미지원
        guard item.scope != .organization else {
            AppLog.info("[MemoryStore] organization scope not yet supported: \(item.title)")
            return false
        }
        // 승인 필요 항목: pendingReview에 추가, 저장 대기
        if item.sensitivity.requiresApproval && !item.isUserApproved {
            let candidate = MemoryCandidate(
                id: item.id,
                suggestedScope: item.scope,
                suggestedSensitivity: item.sensitivity,
                title: item.title,
                content: item.content,
                sourceRoomID: item.sourceRoomID,
                reason: "민감 정보 — 사용자 승인 필요"
            )
            pendingReviewCandidates.append(MemoryReviewCandidate(candidate: candidate))
            AppLog.info("[MemoryStore] pending approval: \(item.title)")
            return false
        }

        persist(item)
        save()
        return true
    }

    /// 후보로부터 MemoryItem을 생성해 저장 시도
    @discardableResult
    func addCandidate(_ candidate: MemoryCandidate) -> Bool {
        guard !candidate.isStorageBlocked else { return false }
        let item = MemoryItem(
            id: candidate.id,
            scope: candidate.suggestedScope,
            roomID: candidate.sourceRoomID,
            title: candidate.title,
            content: candidate.content,
            sourceRoomID: candidate.sourceRoomID,
            confidence: candidate.confidence,
            sensitivity: candidate.suggestedSensitivity,
            isUserApproved: false,
            isAutoExtracted: true
        )
        return add(item)
    }

    // MARK: - Update / Delete

    func update(_ updated: MemoryItem) {
        var item = updated
        item.updatedAt = Date()
        remove(id: updated.id)
        persist(item)
        save()
    }

    func remove(id: UUID) {
        // room memories
        for (roomID, items) in memoriesByRoom {
            memoriesByRoom[roomID] = items.filter { $0.id != id }
        }
        userProfileMemories.removeAll { $0.id == id }
        proceduralMemories.removeAll { $0.id == id }
        for (domain, items) in domainMemories {
            domainMemories[domain] = items.filter { $0.id != id }
        }
    }

    func markUsed(_ id: UUID) {
        func markIn(_ items: inout [MemoryItem]) {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].lastUsedAt = Date()
            }
        }
        for key in memoriesByRoom.keys { markIn(&memoriesByRoom[key]!) }
        markIn(&userProfileMemories)
        markIn(&proceduralMemories)
        for key in domainMemories.keys { markIn(&domainMemories[key]!) }
    }

    // MARK: - Approve pending

    func approvePending(id: UUID, action: MemoryReviewCandidate.Action) {
        guard let idx = pendingReviewCandidates.firstIndex(where: { $0.id == id }) else { return }
        let review = pendingReviewCandidates.remove(at: idx)
        switch action {
        case .doNotRemember:
            break
        case .rememberForThisRoom:
            let c = review.candidate
            let item = MemoryItem(
                id: c.id,
                scope: .room,
                roomID: c.sourceRoomID,
                title: c.title,
                content: c.content,
                sourceRoomID: c.sourceRoomID,
                confidence: c.confidence,
                sensitivity: c.suggestedSensitivity,
                isUserApproved: true,
                isAutoExtracted: true
            )
            persist(item)
            save()
        case .rememberAlways:
            let c = review.candidate
            let item = MemoryItem(
                id: c.id,
                scope: .userProfile,
                title: c.title,
                content: c.content,
                sourceRoomID: c.sourceRoomID,
                confidence: c.confidence,
                sensitivity: .workPreference,
                isUserApproved: true,
                isAutoExtracted: true
            )
            persist(item)
            save()
        }
    }

    // MARK: - Query helpers

    func roomMemories(for roomID: UUID) -> [MemoryItem] {
        (memoriesByRoom[roomID] ?? []).filter { !$0.isExpired }
    }

    func allProcedural() -> [MemoryItem] {
        proceduralMemories.filter { !$0.isExpired }
    }

    func allUserProfile() -> [MemoryItem] {
        userProfileMemories.filter { !$0.isExpired }
    }

    func domainItems(for domain: MemoryDomain) -> [MemoryItem] {
        (domainMemories[domain] ?? []).filter { !$0.isExpired }
    }

    // MARK: - Internal persist

    private func persist(_ item: MemoryItem) {
        switch item.scope {
        case .turn:
            break  // turn memory는 저장 안 함
        case .room, .agentInRoom:
            guard let roomID = item.roomID else { return }
            var list = memoriesByRoom[roomID] ?? []
            list.removeAll { $0.id == item.id }
            list.append(item)
            memoriesByRoom[roomID] = list
        case .userProfile:
            userProfileMemories.removeAll { $0.id == item.id }
            userProfileMemories.append(item)
        case .procedural:
            proceduralMemories.removeAll { $0.id == item.id }
            proceduralMemories.append(item)
        case .domain:
            let key = item.domain ?? .general
            var list = domainMemories[key] ?? []
            list.removeAll { $0.id == item.id }
            list.append(item)
            domainMemories[key] = list
        case .organization:
            break  // organization scope 미지원
        }
    }

    // MARK: - Persistence (UserDefaults JSON)

    private let roomsKey = "MemoryStore.memoriesByRoom"
    private let profileKey = "MemoryStore.userProfile"
    private let proceduralKey = "MemoryStore.procedural"
    private let domainKey = "MemoryStore.domain"

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(memoriesByRoom) {
            UserDefaults.standard.set(data, forKey: roomsKey)
        }
        if let data = try? encoder.encode(userProfileMemories) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
        if let data = try? encoder.encode(proceduralMemories) {
            UserDefaults.standard.set(data, forKey: proceduralKey)
        }
        if let data = try? encoder.encode(domainMemories) {
            UserDefaults.standard.set(data, forKey: domainKey)
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: roomsKey),
           let decoded = try? decoder.decode([UUID: [MemoryItem]].self, from: data) {
            memoriesByRoom = decoded
        }
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? decoder.decode([MemoryItem].self, from: data) {
            userProfileMemories = decoded
        }
        if let data = UserDefaults.standard.data(forKey: proceduralKey),
           let decoded = try? decoder.decode([MemoryItem].self, from: data) {
            proceduralMemories = decoded
        }
        if let data = UserDefaults.standard.data(forKey: domainKey),
           let decoded = try? decoder.decode([MemoryDomain: [MemoryItem]].self, from: data) {
            domainMemories = decoded
        }
    }
}
