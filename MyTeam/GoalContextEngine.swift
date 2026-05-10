import Foundation

enum GoalContextEngine {
    static func referencesRecentArtifact(_ message: String) -> Bool {
        let lower = message.lowercased()
        let markers = [
            "이거",
            "방금",
            "그거",
            "아까",
            "위 내용",
            "방금 만든",
            "그 파일",
            "만든 거",
            "바로 전",
            "직전에 만든"
        ]
        return markers.contains { lower.contains($0) }
    }

    static func latestReferencedArtifactID(
        message: String,
        context: RoomGoalContext?
    ) -> UUID? {
        guard referencesRecentArtifact(message),
              let context,
              let latest = context.recentArtifactIDs.first
        else { return nil }
        return latest
    }
}
