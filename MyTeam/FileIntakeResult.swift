import Foundation

enum DocumentIngestionFormat: String, Codable, Equatable {
    case plainText
    case pdf
    case xlsx
    case docx
    case pptx
    case hwp    // Round 277: HWP/HWPX (한글과컴퓨터)
}

enum DocumentIngestionWarning: String, Codable, Equatable {
    case truncated
    case imageOnlyPDF
    case encryptedFile
    case unsupportedStructure
    case sparseSheetCompacted
    case sheetLimitReached
    case rowLimitReached
    case cellLimitReached
}

struct FileIntakeResult: Equatable {
    enum Status: String, Codable {
        case ready
        case unsupported
        case planned
        case blocked
        case tooLarge
        case readFailed
        case empty
    }

    let status: Status
    let request: FileIntakeRequest
    let extractedText: String?
    let normalizedText: String?
    let detectedFormat: DocumentIngestionFormat?
    let extractionWarnings: [String]
    let metadataSummary: String?
    let userMessage: String
}
