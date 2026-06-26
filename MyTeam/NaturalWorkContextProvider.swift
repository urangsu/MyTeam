import Foundation

struct NaturalWorkContextSnapshot: Sendable {
    let context: NaturalWorkContext
    let chatHistory: [AgentWindowManager.ChatLog]
}

@MainActor
final class WorkContextMemory {
    static let shared = WorkContextMemory()

    private var lastCompanyByRoom: [UUID: CompanyIdentity] = [:]
    private var lastWorkTypeByRoom: [UUID: NaturalWorkType] = [:]

    private init() {}

    func lastCompanyIdentity(roomID: UUID) -> CompanyIdentity? {
        lastCompanyByRoom[roomID]
    }

    func lastWorkType(roomID: UUID) -> NaturalWorkType? {
        lastWorkTypeByRoom[roomID]
    }

    func record(plan: NaturalWorkPlan, roomID: UUID) {
        lastWorkTypeByRoom[roomID] = plan.workType
        if let company = plan.request.entities.compactMap(companyName(from:)).first {
            lastCompanyByRoom[roomID] = CompanyIdentity(
                displayName: company,
                stockCode: plan.request.entities.compactMap(stockCode(from:)).first,
                dartCorpCode: plan.request.entities.compactMap(corpCode(from:)).first,
                source: "natural_work"
            )
        }
    }

    private func companyName(from entity: NaturalEntity) -> String? {
        if case .companyName(let value) = entity { return value }
        return nil
    }

    private func stockCode(from entity: NaturalEntity) -> String? {
        if case .stockCode(let value) = entity { return value }
        return nil
    }

    private func corpCode(from entity: NaturalEntity) -> String? {
        if case .corpCode(let value) = entity { return value }
        return nil
    }
}

@MainActor
struct NaturalWorkContextProvider {
    static func snapshot(
        roomID: UUID,
        manager: AgentWindowManager,
        pendingAttachments: [ChatAttachment] = []
    ) -> NaturalWorkContextSnapshot {
        let recentMessages = manager.rooms
            .first(where: { $0.id == roomID })?
            .messages
            .suffix(8)
            .filter { !$0.isSystem } ?? []
        let recentArtifactEntries = manager.recentArtifactIndexEntries(for: roomID)
        let activeArtifactID = recentArtifactEntries.first?.artifactID
        let recentArtifacts = Array(manager.recentArtifacts(for: roomID).prefix(5))
        let userLocation = UserDefaults.standard.string(forKey: "userLocation")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        return NaturalWorkContextSnapshot(
            context: NaturalWorkContext(
                roomID: roomID,
                activeArtifactID: activeArtifactID,
                recentArtifacts: recentArtifacts,
                pendingAttachments: pendingAttachments,
                recentMessageTexts: recentMessages.map(\.text),
                lastCompanyIdentity: WorkContextMemory.shared.lastCompanyIdentity(roomID: roomID),
                lastWorkType: WorkContextMemory.shared.lastWorkType(roomID: roomID),
                userLocation: userLocation
            ),
            chatHistory: Array(recentMessages)
        )
    }
}
