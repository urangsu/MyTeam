import Foundation

enum RecentArtifactReuseService {
    static func canHandle(
        _ message: String,
        context: RoomGoalContext?,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        GoalContextEngine.referencesRecentArtifact(message)
            && context?.recentArtifactIDs.isEmpty == false
            && documentType(from: message) != nil
            && RecentArtifactContentResolver.canResolveLatestMarkdownArtifact(roomID: roomID, manager: manager)
    }

    @MainActor
    static func makeRequest(
        message: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> UniversalDocumentSkillRequest? {
        guard let type = documentType(from: message) else { return nil }
        guard let resolved = await RecentArtifactContentResolver.resolveLatestMarkdownArtifact(
            roomID: roomID,
            manager: manager,
            allowGlobalFallback: false
        ) else {
            return nil
        }

        return UniversalDocumentSkillService.extractRequest(
            from: message,
            type: type,
            sourceText: resolved.sourceText,
            sourceName: resolved.sourceName
        )
    }

    static func documentType(from message: String) -> UniversalDocumentSkillType? {
        GoalContextEngine.documentTypeFromArtifactReuseRequest(message)
    }
}
