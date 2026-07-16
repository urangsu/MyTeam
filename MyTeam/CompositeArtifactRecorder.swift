import Foundation

enum CompositeArtifactRecorder {
    static func write(
        result: NaturalWorkResult,
        originalText: String,
        roomID: UUID,
        workflowID: UUID
    ) async -> IndexedArtifact? {
        return await CompositeWorkArtifactWriter.write(
            result: result,
            originalText: originalText,
            roomID: roomID,
            workflowID: workflowID
        )
    }
}
