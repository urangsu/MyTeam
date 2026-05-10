import Foundation

enum FileIntakeServiceError: Error {
    case invalidURL
}

enum FileIntakeService {
    static let maxExtractedCharacters = 20_000

    static func makeRequest(
        fileURL: URL,
        source: FileIntakeRequest.Source
    ) throws -> FileIntakeRequest {
        guard fileURL.isFileURL else {
            throw FileIntakeServiceError.invalidURL
        }

        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values?.fileSize ?? 0)
        let filename = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()

        return FileIntakeRequest(
            id: UUID(),
            source: source,
            fileURL: fileURL,
            originalFilename: filename.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : filename,
            fileExtension: ext,
            fileSizeBytes: size,
            requestedDocumentType: UniversalDocumentSkillService.detectSkillType(from: filename),
            createdAt: Date()
        )
    }

    static func readText(from request: FileIntakeRequest) -> FileIntakeResult {
        let decision = FileIntakePolicy.decision(for: request)
        switch decision.status {
        case .blocked:
            return FileIntakeResult(
                status: .blocked,
                request: request,
                extractedText: nil,
                userMessage: decision.message
            )
        case .tooLarge:
            return FileIntakeResult(
                status: .tooLarge,
                request: request,
                extractedText: nil,
                userMessage: decision.message
            )
        case .planned:
            return FileIntakeResult(
                status: .planned,
                request: request,
                extractedText: nil,
                userMessage: decision.message
            )
        case .allowed:
            break
        }

        let accessGranted = request.fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                request.fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: request.fileURL)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .utf16LittleEndian)
                ?? String(data: data, encoding: .utf16BigEndian)

            guard var extracted = text?.trimmingCharacters(in: .whitespacesAndNewlines), !extracted.isEmpty else {
                return FileIntakeResult(
                    status: .empty,
                    request: request,
                    extractedText: nil,
                    userMessage: "파일이 비어 있습니다."
                )
            }

            if extracted.count > maxExtractedCharacters {
                extracted = String(extracted.prefix(maxExtractedCharacters))
            }

            return FileIntakeResult(
                status: .ready,
                request: request,
                extractedText: extracted,
                userMessage: "파일을 읽었습니다."
            )
        } catch {
            return FileIntakeResult(
                status: .readFailed,
                request: request,
                extractedText: nil,
                userMessage: "파일을 읽지 못했습니다. txt, md, csv 파일로 다시 시도해 주세요."
            )
        }
    }

    static func universalDocumentMessage(
        from result: FileIntakeResult,
        type: UniversalDocumentSkillType
    ) -> String {
        let title = result.request.originalFilename
        let source = result.extractedText ?? ""
        return """
        파일 내용을 바탕으로 \(type.displayName.lowercased()) 초안을 만들 수 있습니다.

        파일명: \(title)

        원문:
        \(source)
        """
    }
}
