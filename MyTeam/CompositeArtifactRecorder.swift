import Foundation

enum CompositeArtifactRecorder {
    static func write(
        result: NaturalWorkResult,
        originalText: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> IndexedArtifact? {
        let workflowID = await MainActor.run { manager.currentWorkflowID(for: roomID) }
        return await CompositeWorkArtifactWriter.write(
            result: result,
            originalText: originalText,
            roomID: roomID,
            workflowID: workflowID
        )
    }
}
