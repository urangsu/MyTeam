import Foundation

struct RecentArtifactSourceBinding: Codable, Equatable {
    let roomID: UUID
    let artifactID: String
    let filename: String
    let contentHash: String
    let fileSizeBytes: Int64
    let modifiedAt: Date
    let createdAt: Date
}
