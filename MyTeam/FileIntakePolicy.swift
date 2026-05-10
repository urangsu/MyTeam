import Foundation

struct FileIntakeDecision: Equatable {
    enum Status: String, Codable {
        case allowed
        case planned
        case blocked
        case tooLarge
    }

    let status: Status
    let message: String
}

enum FileIntakePolicy {
    static let maxFileSizeBytes: Int64 = 2 * 1024 * 1024

    static let readableExtensions: Set<String> = [
        "txt", "md", "markdown", "csv"
    ]

    static let plannedExtensions: Set<String> = [
        "pdf", "docx", "xlsx", "pptx"
    ]

    static let blockedExtensions: Set<String> = [
        "app", "pkg", "dmg", "sh", "command", "zsh", "bash", "py", "js", "exe"
    ]

    static func decision(for request: FileIntakeRequest) -> FileIntakeDecision {
        let ext = request.fileExtension.lowercased()

        if request.fileSizeBytes > maxFileSizeBytes {
            return .init(status: .tooLarge, message: "파일이 너무 큽니다. 먼저 2MB 이하 파일을 지원합니다.")
        }

        if blockedExtensions.contains(ext) {
            return .init(status: .blocked, message: "이 파일 형식은 안전을 위해 열 수 없습니다.")
        }

        if readableExtensions.contains(ext) {
            return .init(status: .allowed, message: "읽을 수 있는 파일입니다.")
        }

        if plannedExtensions.contains(ext) {
            return .init(status: .planned, message: "이 파일 형식은 준비 중입니다. 먼저 txt, md, csv를 지원합니다.")
        }

        return .init(status: .blocked, message: "지원하지 않는 파일 형식입니다.")
    }
}
