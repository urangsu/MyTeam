import Foundation

struct FileIntakeRequest: Identifiable, Equatable {
    enum Source: String, Codable {
        case filePicker
        case dragAndDrop
        case clipboard
    }

    let id: UUID
    let source: Source
    let fileURL: URL
    let originalFilename: String
    let fileExtension: String
    let fileSizeBytes: Int64
    let requestedDocumentType: UniversalDocumentSkillType?
    let createdAt: Date
}
