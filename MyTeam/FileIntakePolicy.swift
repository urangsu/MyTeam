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
            return .init(status: .tooLarge, message: "파일이 너무 큽니다. 현재는 2MB 이하 파일을 지원합니다.")
        }

        if blockedExtensions.contains(ext) {
            return .init(status: .blocked, message: "이 파일 형식은 안전을 위해 열 수 없습니다.")
        }

        if readableExtensions.contains(ext) {
            return .init(status: .allowed, message: "이 파일을 읽을 수 있습니다. 바로 문서 작업을 진행할 수 있습니다.")
        }

        if plannedExtensions.contains(ext) {
            let message = extToPlannedMessage(ext)
            return .init(status: .planned, message: message)
        }

        return .init(status: .blocked, message: "지원하지 않는 파일 형식입니다.")
    }

    private static func extToPlannedMessage(_ ext: String) -> String {
        switch ext {
        case "pdf":
            return "PDF 읽기는 준비 중입니다. 현재는 텍스트/마크다운/CSV 파일을 먼저 지원합니다."
        case "docx":
            return "Word 문서 읽기는 준비 중입니다. 지금은 내용을 텍스트로 복사해 붙여 넣으면 문서화할 수 있습니다."
        case "xlsx":
            return "Excel 파일 분석은 준비 중입니다. 현재는 CSV를 먼저 지원합니다."
        case "pptx":
            return "PowerPoint 읽기는 준비 중입니다. 지금은 슬라이드 내용을 텍스트로 붙여 넣어 요약할 수 있습니다."
        default:
            return "이 파일 형식은 준비 중입니다. 현재는 텍스트/마크다운/CSV를 지원합니다."
        }
    }
}
