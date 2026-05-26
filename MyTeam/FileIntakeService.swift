import Foundation
import PDFKit
import CoreXLSX
import ZIPFoundation

enum FileIntakeServiceError: Error {
    case invalidURL
}

private struct DocumentIngestionResult {
    let status: FileIntakeResult.Status
    let format: DocumentIngestionFormat?
    let normalizedText: String?
    let warnings: [DocumentIngestionWarning]
    let metadataSummary: String?
    let userMessage: String
}

enum FileIntakeService {
    static let maxExtractedCharacters = 20_000
    private static let maxPDFPages = 20
    private static let maxPPTXSlides = 20
    private static let maxXLSXSheets = 10
    private static let maxXLSXRowsPerSheet = 200
    private static let maxXLSXCellsPerRow = 20

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
                normalizedText: nil,
                detectedFormat: nil,
                extractionWarnings: [],
                metadataSummary: nil,
                userMessage: decision.message
            )
        case .tooLarge:
            return FileIntakeResult(
                status: .tooLarge,
                request: request,
                extractedText: nil,
                normalizedText: nil,
                detectedFormat: nil,
                extractionWarnings: [],
                metadataSummary: nil,
                userMessage: decision.message
            )
        case .planned:
            return FileIntakeResult(
                status: .planned,
                request: request,
                extractedText: nil,
                normalizedText: nil,
                detectedFormat: nil,
                extractionWarnings: [],
                metadataSummary: nil,
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

        let ingestion = ingest(request)
        return FileIntakeResult(
            status: ingestion.status,
            request: request,
            extractedText: ingestion.normalizedText,
            normalizedText: ingestion.normalizedText,
            detectedFormat: ingestion.format,
            extractionWarnings: ingestion.warnings.map(\.rawValue),
            metadataSummary: ingestion.metadataSummary,
            userMessage: ingestion.userMessage
        )
    }

    static func universalDocumentMessage(
        from result: FileIntakeResult,
        type: UniversalDocumentSkillType
    ) -> String {
        let title = result.request.originalFilename
        let source = (result.normalizedText ?? result.extractedText) ?? ""
        return """
        파일 내용을 바탕으로 \(type.displayName.lowercased()) 초안을 만들 수 있습니다.

        파일명: \(title)

        원문:
        \(source)
        """
    }

    @MainActor
    static func writeFirstResultCard(
        from result: FileIntakeResult,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> IndexedArtifact? {
        guard result.status == .ready,
              let sourceText = result.normalizedText ?? result.extractedText,
              !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let workflowID = manager.currentWorkflowID ?? UUID()
        let markdown = buildFirstResultCardMarkdown(result: result, sourceText: sourceText)
        let filename = firstResultCardFilename(for: result)
        let fileURL: URL
        do {
            fileURL = try safeWritableWorkspaceURL(
                filename: filename,
                context: ToolExecutionContext.current(workflowID: workflowID, roomID: roomID)
            )
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[FileIntakeService] first result card 저장 실패: \(error.localizedDescription)")
            return nil
        }

        let savedFilename = fileURL.lastPathComponent
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: firstResultCardTitle(for: result),
            type: .text,
            filename: savedFilename,
            relativePath: savedFilename,
            preview: markdownPreview(markdown),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            contentHash: StableContentHash.sha256Hex(markdown),
            fileSizeBytes: Int64(markdown.utf8.count),
            roomID: roomID.uuidString
        )

        await ArtifactStore.shared.registerArtifact(artifact)
        manager.addRecentArtifactIndexEntry(
            RecentArtifactIndexEntry(
                artifactID: artifact.id,
                roomID: roomID,
                filename: savedFilename,
                artifactType: artifact.type.rawValue,
                createdAt: Date(),
                contentHash: artifact.contentHash,
                fileSizeBytes: artifact.fileSizeBytes
            )
        )

        NotificationCenter.default.post(
            name: .workflowCompleted,
            object: nil,
            userInfo: [
                "workflowID": workflowID.uuidString,
                "roomID": roomID,
                "artifacts": [artifact]
            ]
        )

        return artifact
    }

    static func extractAttachmentText(from url: URL) -> String? {
        do {
            let request = try makeRequest(fileURL: url, source: .filePicker)
            let result = readText(from: request)
            return result.normalizedText ?? result.extractedText
        } catch {
            return nil
        }
    }

    private static func buildFirstResultCardMarkdown(
        result: FileIntakeResult,
        sourceText: String
    ) -> String {
        let filename = result.request.originalFilename
        let kind = intakeKind(result: result, sourceText: sourceText)
        let summary = summaryBullets(from: sourceText, limit: 4)
        let actionItems = actionItemBullets(from: sourceText, kind: kind)
        let cautionItems = cautionBullets(from: result, sourceText: sourceText, kind: kind)
        let nextActions = nextActionBullets(kind: kind)
        let metadata = [
            result.detectedFormat.map { "- 형식: \($0.rawValue)" },
            result.metadataSummary.map { "- 추출 정보: \($0)" },
            result.extractionWarnings.isEmpty ? nil : "- 경고: \(result.extractionWarnings.joined(separator: ", "))"
        ].compactMap { $0 }

        return """
        # \(firstResultCardTitle(for: result))

        원본: \(filename)

        ## 요약
        \(summary.map { "- \($0)" }.joined(separator: "\n"))

        ## 해야 할 일
        \(actionItems.map { "- \($0)" }.joined(separator: "\n"))

        ## 주의할 점
        \(cautionItems.map { "- \($0)" }.joined(separator: "\n"))

        ## 다음 버튼
        \(nextActions.map { "- \($0)" }.joined(separator: "\n"))

        ## 처리 정보
        \(metadata.isEmpty ? "- 로컬 파일 읽기 결과로 만든 첫 카드입니다." : metadata.joined(separator: "\n"))
        """
    }

    private enum IntakeKind {
        case mail
        case spreadsheet
        case document
    }

    private static func intakeKind(result: FileIntakeResult, sourceText: String) -> IntakeKind {
        if result.detectedFormat == .xlsx { return .spreadsheet }
        let lower = (result.request.originalFilename + "\n" + sourceText.prefix(1_000)).lowercased()
        if lower.contains("from:") || lower.contains("subject:") || lower.contains("보낸사람")
            || lower.contains("받는사람") || lower.contains("메일") || lower.contains("이메일") {
            return .mail
        }
        return .document
    }

    private static func summaryBullets(from text: String, limit: Int) -> [String] {
        let candidates = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard line.count >= 12 else { return false }
                guard !line.hasPrefix("#"), !line.hasPrefix("|"), !line.hasPrefix("- 형식:") else { return false }
                return true
            }

        let bullets = candidates.prefix(limit).map { compactLine($0, maxLength: 120) }
        return bullets.isEmpty ? ["파일 내용을 읽었지만 자동 요약할 충분한 문장을 찾지 못했습니다."] : Array(bullets)
    }

    private static func actionItemBullets(from text: String, kind: IntakeKind) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let actionKeywords = ["요청", "확인", "검토", "회신", "답장", "제출", "마감", "기한", "필요", "해야", "보내", "공유"]
        let matches = lines.filter { line in
            actionKeywords.contains { line.localizedCaseInsensitiveContains($0) }
        }
        let extracted = matches.prefix(4).map { compactLine($0, maxLength: 110) }
        if !extracted.isEmpty { return Array(extracted) }

        switch kind {
        case .mail:
            return ["메일 요청사항을 확인하고 답장 필요 여부를 결정하세요.", "마감일이나 첨부 요청이 있는지 한 번 더 확인하세요."]
        case .spreadsheet:
            return ["핵심 수치와 이상값을 확인하세요.", "필요하면 표 요약이나 이상 후보 검토를 이어서 요청하세요."]
        case .document:
            return ["중요한 날짜, 금액, 담당자, 의사결정 항목을 확인하세요.", "필요하면 체크리스트나 보고서 초안으로 변환하세요."]
        }
    }

    private static func cautionBullets(
        from result: FileIntakeResult,
        sourceText: String,
        kind: IntakeKind
    ) -> [String] {
        var cautions: [String] = []
        if result.extractionWarnings.contains(DocumentIngestionWarning.truncated.rawValue) {
            cautions.append("문서가 길어 일부만 읽었습니다. 중요한 뒷부분이 있으면 파일을 나눠 다시 올려주세요.")
        }
        if result.extractionWarnings.contains(DocumentIngestionWarning.imageOnlyPDF.rawValue) {
            cautions.append("스캔 이미지나 배치 요소는 빠졌을 수 있습니다. 이미지 OCR/캡처도 함께 확인하는 것이 좋습니다.")
        }
        if sourceText.count < 200 {
            cautions.append("읽은 텍스트가 짧습니다. 원본이 이미지 중심이면 추출이 부족할 수 있습니다.")
        }
        if kind == .mail {
            cautions.append("메일 발송이나 삭제는 자동으로 하지 않습니다. 답장 초안은 확인 후 직접 보내세요.")
        }
        return cautions.isEmpty ? ["이 카드는 로컬 추출 결과 기반입니다. 법률·세무·투자 판단은 원문과 함께 확인하세요."] : cautions
    }

    private static func nextActionBullets(kind: IntakeKind) -> [String] {
        switch kind {
        case .mail:
            return ["답장 초안 만들기", "해야 할 일만 체크리스트로 만들기", "마감일과 담당자만 뽑기"]
        case .spreadsheet:
            return ["표로 다시 정리하기", "이상한 수치 후보 찾기", "요약 보고서 만들기"]
        case .document:
            return ["핵심 요약 더 짧게 만들기", "회의록/보고서 형식으로 바꾸기", "할 일 체크리스트 만들기"]
        }
    }

    private static func firstResultCardTitle(for result: FileIntakeResult) -> String {
        let name = result.request.originalFilename
        switch intakeKind(result: result, sourceText: result.normalizedText ?? result.extractedText ?? "") {
        case .mail: return "메일 할 일 카드"
        case .spreadsheet: return "표 요약 카드"
        case .document: return "\(name) 요약 카드"
        }
    }

    private static func firstResultCardFilename(for result: FileIntakeResult) -> String {
        let stem = result.request.originalFilename
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(String(stem.prefix(40)))_요약카드.md"
    }

    private static func compactLine(_ line: String, maxLength: Int) -> String {
        let collapsed = line
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxLength else { return collapsed }
        return String(collapsed.prefix(maxLength - 1)) + "..."
    }

    private static func markdownPreview(_ markdown: String) -> String {
        String(markdown.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ingest(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        switch request.fileExtension.lowercased() {
        case "txt", "md", "markdown", "csv":
            return ingestPlainText(request)
        case "pdf":
            return ingestPDF(request)
        case "xlsx":
            return ingestXLSX(request)
        case "docx":
            return ingestDOCX(request)
        case "pptx":
            return ingestPPTX(request)
        case "hwp", "hwpx":
            return ingestHWP(request)
        default:
            return DocumentIngestionResult(
                status: .unsupported,
                format: nil,
                normalizedText: nil,
                warnings: [],
                metadataSummary: nil,
                userMessage: "지원하지 않는 파일 형식입니다."
            )
        }
    }

    private static func ingestPlainText(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        do {
            let data = try Data(contentsOf: request.fileURL)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .utf16LittleEndian)
                ?? String(data: data, encoding: .utf16BigEndian)

            guard var extracted = text?.trimmingCharacters(in: .whitespacesAndNewlines), !extracted.isEmpty else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .plainText,
                    normalizedText: nil,
                    warnings: [],
                    metadataSummary: "plainText empty",
                    userMessage: "파일이 비어 있습니다."
                )
            }

            var warnings: [DocumentIngestionWarning] = []
            if extracted.count > maxExtractedCharacters {
                extracted = String(extracted.prefix(maxExtractedCharacters))
                warnings.append(.truncated)
            }

            return DocumentIngestionResult(
                status: .ready,
                format: .plainText,
                normalizedText: extracted,
                warnings: warnings,
                metadataSummary: "plainText chars=\(extracted.count)",
                userMessage: warnings.isEmpty ? "파일을 읽었습니다." : "파일을 읽었습니다. 긴 내용은 일부만 사용합니다."
            )
        } catch {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .plainText,
                normalizedText: nil,
                warnings: [],
                metadataSummary: "plainText readFailed",
                userMessage: "파일을 읽지 못했습니다. 권한이 없거나 지원하지 않는 인코딩일 수 있습니다."
            )
        }
    }

    private static func ingestPDF(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        guard let document = PDFDocument(url: request.fileURL) else {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .pdf,
                normalizedText: nil,
                warnings: [.encryptedFile],
                metadataSummary: "pdf unreadable",
                userMessage: "암호가 걸렸거나 파일을 열 수 없습니다."
            )
        }

        let pageCount = document.pageCount
        var sections: [String] = [
            "# \(request.originalFilename)",
            "",
            "## 문서 개요",
            "- 형식: PDF",
            "- 페이지 수: \(pageCount)",
            ""
        ]
        var warnings: [DocumentIngestionWarning] = []
        var collectedCharacters = 0
        var nonEmptyPageCount = 0

        let pageLimit = min(pageCount, maxPDFPages)
        if pageCount > maxPDFPages {
            warnings.append(.truncated)
        }

        for index in 0..<pageLimit {
            guard let page = document.page(at: index) else { continue }
            let rawText = page.string?
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !rawText.isEmpty {
                nonEmptyPageCount += 1
            }

            let normalizedPage = normalizedParagraphs(from: rawText)
            guard !normalizedPage.isEmpty else { continue }

            let remainingBudget = maxExtractedCharacters - collectedCharacters
            guard remainingBudget > 0 else {
                warnings.append(.truncated)
                break
            }

            let clippedPage = String(normalizedPage.prefix(remainingBudget))
            sections.append("## 페이지 \(index + 1)")
            sections.append(clippedPage)
            sections.append("")
            collectedCharacters += clippedPage.count

            if clippedPage.count < normalizedPage.count {
                warnings.append(.truncated)
                break
            }
        }

        let normalizedText = sections.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty, collectedCharacters > 0 else {
            return DocumentIngestionResult(
                status: .empty,
                format: .pdf,
                normalizedText: nil,
                warnings: [.imageOnlyPDF],
                metadataSummary: "pdf empty",
                userMessage: "텍스트를 거의 찾지 못했습니다. 스캔 문서일 수 있습니다."
            )
        }

        if nonEmptyPageCount <= 1 && collectedCharacters < 120 {
            warnings.append(.imageOnlyPDF)
        }

        let metadataSummary = "pdf pages=\(pageCount) extractedPages=\(min(pageLimit, nonEmptyPageCount)) warnings=\(warnings.count)"
        let userMessage: String
        if warnings.contains(.imageOnlyPDF) {
            userMessage = "파일을 읽었습니다. 텍스트만 읽었고 스캔 이미지나 배치 요소는 빠질 수 있습니다."
        } else if warnings.contains(.truncated) {
            userMessage = "파일을 읽었습니다. 긴 문서라 일부만 사용합니다."
        } else {
            userMessage = "파일을 읽었습니다. 이 내용을 바탕으로 문서 초안을 만들 수 있습니다."
        }

        return DocumentIngestionResult(
            status: .ready,
            format: .pdf,
            normalizedText: normalizedText,
            warnings: deduplicated(warnings),
            metadataSummary: metadataSummary,
            userMessage: userMessage
        )
    }

    private static func ingestXLSX(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        do {
            let data = try Data(contentsOf: request.fileURL)
            let file = try XLSXFile(data: data)

            let workbooks = try file.parseWorkbooks()
            guard let workbook = workbooks.first else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .xlsx,
                    normalizedText: nil,
                    warnings: [],
                    metadataSummary: "xlsx empty workbook",
                    userMessage: "시트를 찾지 못했습니다."
                )
            }

            let sharedStrings = try file.parseSharedStrings()
            let sheetPairs = try file.parseWorksheetPathsAndNames(workbook: workbook)
            if sheetPairs.isEmpty {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .xlsx,
                    normalizedText: nil,
                    warnings: [],
                    metadataSummary: "xlsx empty sheets",
                    userMessage: "시트를 찾지 못했습니다."
                )
            }

            var warnings: [DocumentIngestionWarning] = []
            if sheetPairs.count > maxXLSXSheets {
                warnings.append(.sheetLimitReached)
            }

            var lines: [String] = [
                "# \(request.originalFilename)",
                "",
                "## 문서 개요",
                "- 형식: XLSX",
                "- 시트 수: \(sheetPairs.count)",
                ""
            ]
            var includedSheets = 0
            var totalCharacters = lines.joined(separator: "\n").count

            for (index, pair) in sheetPairs.enumerated() {
                if index >= maxXLSXSheets {
                    break
                }
                let (name, path) = pair
                let worksheet = try file.parseWorksheet(at: path)
                let sheetName = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : "시트 \(index + 1)")
                let sheetMarkdown = renderWorksheetMarkdown(
                    worksheet: worksheet,
                    sheetName: sheetName,
                    sharedStrings: sharedStrings,
                    warnings: &warnings
                )
                guard !sheetMarkdown.isEmpty else { continue }

                let remainingBudget = maxExtractedCharacters - totalCharacters
                guard remainingBudget > 0 else {
                    warnings.append(.truncated)
                    break
                }

                let clipped = String(sheetMarkdown.prefix(remainingBudget))
                lines.append(clipped)
                lines.append("")
                totalCharacters += clipped.count + 1
                includedSheets += 1

                if clipped.count < sheetMarkdown.count {
                    warnings.append(.truncated)
                    break
                }
            }

            let normalizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard includedSheets > 0, normalizedText.isEmpty == false else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .xlsx,
                    normalizedText: nil,
                    warnings: [.unsupportedStructure],
                    metadataSummary: "xlsx no usable sheets",
                    userMessage: "읽을 수 있는 표 구조를 찾지 못했습니다."
                )
            }

            let metadataSummary = "xlsx sheets=\(sheetPairs.count) included=\(includedSheets) warnings=\(warnings.count)"
            let userMessage: String
            if warnings.isEmpty {
                userMessage = "파일을 읽었습니다. 이 내용을 바탕으로 문서 초안을 만들 수 있습니다."
            } else {
                userMessage = "파일을 읽었습니다. 표 구조를 중심으로 읽었고 스타일, 병합셀, 수식 결과는 일부 다를 수 있습니다."
            }

            return DocumentIngestionResult(
                status: .ready,
                format: .xlsx,
                normalizedText: normalizedText,
                warnings: deduplicated(warnings),
                metadataSummary: metadataSummary,
                userMessage: userMessage
            )
        } catch {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .xlsx,
                normalizedText: nil,
                warnings: [],
                metadataSummary: "xlsx readFailed",
                userMessage: "파일을 열 수 없습니다. 암호가 걸렸거나 지원하지 않는 XLSX 구조일 수 있습니다."
            )
        }
    }

    private static func ingestDOCX(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        do {
            let entries = try archiveEntries(at: request.fileURL)
            guard let documentData = entries["word/document.xml"] else {
                return DocumentIngestionResult(
                    status: .readFailed,
                    format: .docx,
                    normalizedText: nil,
                    warnings: [.unsupportedStructure],
                    metadataSummary: "docx missing document.xml",
                    userMessage: "파일을 열 수 없습니다. 지원하지 않는 Word 문서 구조일 수 있습니다."
                )
            }

            let parser = DOCXBodyParser()
            guard let parseResult = parser.parse(data: documentData) else {
                return DocumentIngestionResult(
                    status: .readFailed,
                    format: .docx,
                    normalizedText: nil,
                    warnings: [],
                    metadataSummary: "docx parse failed",
                    userMessage: "Word 문서를 읽지 못했습니다."
                )
            }

            var warnings: [DocumentIngestionWarning] = []
            let headerFooterText = docxHeaderFooterSections(from: entries)
            var lines: [String] = [
                "# \(request.originalFilename)",
                "",
                "## 문서 개요",
                "- 형식: DOCX",
                "- 단락 수: \(parseResult.paragraphCount)",
                "- 표 수: \(parseResult.tableCount)",
                "",
            ]

            if !headerFooterText.isEmpty {
                lines.append(contentsOf: [
                    "## 머리말/꼬리말",
                    "",
                    headerFooterText,
                    ""
                ])
            }

            lines.append(contentsOf: [
                "## 본문",
                ""
            ])
            var totalCharacters = lines.joined(separator: "\n").count
            var includedBlocks = 0

            for block in parseResult.blocks {
                let blockMarkdown = renderDOCXBlock(block, warnings: &warnings)
                guard !blockMarkdown.isEmpty else { continue }

                let remainingBudget = maxExtractedCharacters - totalCharacters
                guard remainingBudget > 0 else {
                    warnings.append(.truncated)
                    break
                }

                let clipped = String(blockMarkdown.prefix(remainingBudget))
                lines.append(clipped)
                lines.append("")
                totalCharacters += clipped.count + 1
                includedBlocks += 1

                if clipped.count < blockMarkdown.count {
                    warnings.append(.truncated)
                    break
                }
            }

            let normalizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard includedBlocks > 0, !normalizedText.isEmpty else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .docx,
                    normalizedText: nil,
                    warnings: [.unsupportedStructure],
                    metadataSummary: "docx empty body",
                    userMessage: "읽을 수 있는 본문을 찾지 못했습니다."
                )
            }

            let metadataSummary = "docx paragraphs=\(parseResult.paragraphCount) tables=\(parseResult.tableCount) headersFooters=\(headerFooterText.isEmpty ? 0 : 1) warnings=\(warnings.count)"
            let userMessage = warnings.isEmpty
                ? "파일을 읽었습니다. 이 내용을 바탕으로 문서 초안을 만들 수 있습니다."
                : "파일을 읽었습니다. 표 구조, 리스트, 머리말/꼬리말을 중심으로 읽었고 일부 서식은 생략될 수 있습니다."

            return DocumentIngestionResult(
                status: .ready,
                format: .docx,
                normalizedText: normalizedText,
                warnings: deduplicated(warnings),
                metadataSummary: metadataSummary,
                userMessage: userMessage
            )
        } catch {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .docx,
                normalizedText: nil,
                warnings: [],
                metadataSummary: "docx readFailed",
                userMessage: "파일을 열 수 없습니다. 암호가 걸렸거나 지원하지 않는 Word 문서일 수 있습니다."
            )
        }
    }

    private static func ingestPPTX(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        do {
            let entries = try archiveEntries(at: request.fileURL)
            let slidePaths = entries.keys
                .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") && !$0.contains("/_rels/") }
                .sorted { slideNumber(from: $0) < slideNumber(from: $1) }

            guard !slidePaths.isEmpty else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .pptx,
                    normalizedText: nil,
                    warnings: [.unsupportedStructure],
                    metadataSummary: "pptx empty slides",
                    userMessage: "읽을 수 있는 슬라이드를 찾지 못했습니다."
                )
            }

            var warnings: [DocumentIngestionWarning] = []
            if slidePaths.count > maxPPTXSlides {
                warnings.append(.truncated)
            }

            var lines: [String] = [
                "# \(request.originalFilename)",
                "",
                "## 문서 개요",
                "- 형식: PPTX",
                "- 슬라이드 수: \(slidePaths.count)",
                ""
            ]
            var totalCharacters = lines.joined(separator: "\n").count
            var includedSlides = 0

            for (index, path) in slidePaths.enumerated() {
                if index >= maxPPTXSlides { break }
                guard let slideData = entries[path] else { continue }
                let slideParseResult = PPTXSlideParser().parse(data: slideData)
                let normalizedTexts = slideParseResult.texts.map { singleLine($0) }.filter { !$0.isEmpty }
                let noteTexts = pptxNotesTexts(slidePath: path, entries: entries)
                let normalizedNotes = noteTexts.map { singleLine($0) }.filter { !$0.isEmpty }
                guard !normalizedTexts.isEmpty || !slideParseResult.tables.isEmpty || !normalizedNotes.isEmpty else { continue }

                let slideMarkdown = renderPPTXSlideMarkdown(
                    number: index + 1,
                    texts: normalizedTexts,
                    tables: slideParseResult.tables,
                    notes: normalizedNotes
                )
                let remainingBudget = maxExtractedCharacters - totalCharacters
                guard remainingBudget > 0 else {
                    warnings.append(.truncated)
                    break
                }

                let clipped = String(slideMarkdown.prefix(remainingBudget))
                lines.append(clipped)
                lines.append("")
                totalCharacters += clipped.count + 1
                includedSlides += 1

                if clipped.count < slideMarkdown.count {
                    warnings.append(.truncated)
                    break
                }
            }

            let normalizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard includedSlides > 0, !normalizedText.isEmpty else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .pptx,
                    normalizedText: nil,
                    warnings: [.unsupportedStructure],
                    metadataSummary: "pptx no text slides",
                    userMessage: "텍스트가 있는 슬라이드를 찾지 못했습니다."
                )
            }

            let metadataSummary = "pptx slides=\(slidePaths.count) included=\(includedSlides) warnings=\(warnings.count)"
            let userMessage = warnings.isEmpty
                ? "파일을 읽었습니다. 이 내용을 바탕으로 문서 초안을 만들 수 있습니다."
                : "파일을 읽었습니다. 슬라이드 텍스트, 표, 발표자 노트를 중심으로 읽었고 레이아웃 정보는 생략될 수 있습니다."

            return DocumentIngestionResult(
                status: .ready,
                format: .pptx,
                normalizedText: normalizedText,
                warnings: deduplicated(warnings),
                metadataSummary: metadataSummary,
                userMessage: userMessage
            )
        } catch {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .pptx,
                normalizedText: nil,
                warnings: [],
                metadataSummary: "pptx readFailed",
                userMessage: "파일을 열 수 없습니다. 암호가 걸렸거나 지원하지 않는 PowerPoint 문서일 수 있습니다."
            )
        }
    }

    private static func ingestHWP(_ request: FileIntakeRequest) -> DocumentIngestionResult {
        do {
            let markdown = try HWPFileExtractor.extractMarkdown(from: request.fileURL)
            guard !markdown.isEmpty else {
                return DocumentIngestionResult(
                    status: .empty,
                    format: .hwp,
                    normalizedText: nil,
                    warnings: [],
                    metadataSummary: "hwp empty",
                    userMessage: "파일에서 텍스트를 찾지 못했습니다."
                )
            }

            var warnings: [DocumentIngestionWarning] = []
            var normalized = markdown

            if normalized.count > maxExtractedCharacters {
                normalized = String(normalized.prefix(maxExtractedCharacters))
                warnings.append(.truncated)
            }

            let metadataSummary = "hwp chars=\(normalized.count) warnings=\(warnings.count)"
            let userMessage: String = warnings.isEmpty
                ? "HWP 파일을 마크다운으로 변환했습니다."
                : "HWP 파일을 읽었습니다. 긴 문서라 일부만 사용합니다."

            return DocumentIngestionResult(
                status: .ready,
                format: .hwp,
                normalizedText: normalized,
                warnings: warnings,
                metadataSummary: metadataSummary,
                userMessage: userMessage
            )
        } catch {
            return DocumentIngestionResult(
                status: .readFailed,
                format: .hwp,
                normalizedText: nil,
                warnings: [],
                metadataSummary: "hwp readFailed",
                userMessage: "HWP 파일을 열 수 없습니다. \(error.localizedDescription)"
            )
        }
    }

    private static func renderWorksheetMarkdown(
        worksheet: Worksheet,
        sheetName: String,
        sharedStrings: SharedStrings?,
        warnings: inout [DocumentIngestionWarning]
    ) -> String {
        let rows = worksheet.data?.rows ?? []
        guard !rows.isEmpty else { return "" }

        var rowMatrices: [[String]] = []
        rowMatrices.reserveCapacity(min(rows.count, maxXLSXRowsPerSheet))

        for (index, row) in rows.enumerated() {
            if index >= maxXLSXRowsPerSheet {
                warnings.append(.rowLimitReached)
                break
            }
            let expanded = expandedRow(row, sharedStrings: sharedStrings, warnings: &warnings)
            if expanded.contains(where: { !$0.isEmpty }) {
                rowMatrices.append(expanded)
            }
        }

        guard !rowMatrices.isEmpty else { return "" }

        let headerIndex = rowMatrices.firstIndex(where: { row in
            row.contains(where: { !$0.isEmpty })
        }) ?? 0

        var headers = sanitizeHeaderRow(rowMatrices[headerIndex])
        let maxColumns = max(headers.count, rowMatrices.map(\.count).max() ?? 0)
        if headers.count < maxColumns {
            headers += (headers.count..<maxColumns).map { "열\($0 + 1)" }
        }
        if headers.count > maxXLSXCellsPerRow {
            headers = Array(headers.prefix(maxXLSXCellsPerRow))
            warnings.append(.cellLimitReached)
        }

        var markdownLines: [String] = ["## 시트: \(sheetName)", ""]
        markdownLines.append(markdownTableRow(headers))
        markdownLines.append(markdownTableRow(Array(repeating: "---", count: headers.count)))

        for (rowIndex, row) in rowMatrices.enumerated() where rowIndex != headerIndex {
            var values = padRow(row, to: headers.count)
            if values.count > maxXLSXCellsPerRow {
                values = Array(values.prefix(maxXLSXCellsPerRow))
                warnings.append(.cellLimitReached)
            }
            markdownLines.append(markdownTableRow(values))
        }

        return markdownLines.joined(separator: "\n")
    }

    private static func renderDOCXBlock(
        _ block: DOCXBodyParser.Block,
        warnings: inout [DocumentIngestionWarning]
    ) -> String {
        switch block {
        case .paragraph(let paragraph):
            let text = paragraph.text
            guard !text.isEmpty else { return "" }
            if paragraph.isListItem {
                let indent = String(repeating: "  ", count: max(paragraph.listLevel, 0))
                return "\(indent)- \(text)"
            }
            return text
        case .table(let rows):
            guard !rows.isEmpty else { return "" }
            var headers = sanitizeHeaderRow(rows[0])
            let maxColumns = max(headers.count, rows.map(\.count).max() ?? 0)
            if headers.count < maxColumns {
                headers += (headers.count..<maxColumns).map { "열\($0 + 1)" }
            }
            if headers.count > maxXLSXCellsPerRow {
                headers = Array(headers.prefix(maxXLSXCellsPerRow))
                warnings.append(.cellLimitReached)
            }

            var lines: [String] = [
                markdownTableRow(headers),
                markdownTableRow(Array(repeating: "---", count: headers.count))
            ]
            for row in rows.dropFirst() {
                var values = padRow(row.map { singleLine($0) }, to: headers.count)
                if values.count > maxXLSXCellsPerRow {
                    values = Array(values.prefix(maxXLSXCellsPerRow))
                    warnings.append(.cellLimitReached)
                }
                lines.append(markdownTableRow(values))
            }
            return lines.joined(separator: "\n")
        }
    }

    private static func renderPPTXSlideMarkdown(
        number: Int,
        texts: [String],
        tables: [[[String]]],
        notes: [String]
    ) -> String {
        var lines = ["## 슬라이드 \(number)", ""]
        if let first = texts.first {
            lines.append(first)
        }
        if texts.count > 1 {
            lines.append("")
            for bullet in texts.dropFirst() {
                lines.append("- \(bullet)")
            }
        }
        if !tables.isEmpty {
            for (index, table) in tables.enumerated() {
                let tableMarkdown = renderPPTXTable(table, index: index + 1)
                guard !tableMarkdown.isEmpty else { continue }
                lines.append("")
                lines.append(tableMarkdown)
            }
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append("### 발표자 노트")
            lines.append("")
            for note in notes {
                lines.append("- \(note)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func renderPPTXTable(_ table: [[String]], index: Int) -> String {
        guard !table.isEmpty else { return "" }
        var headers = sanitizeHeaderRow(table[0].map { singleLine($0) })
        let maxColumns = max(headers.count, table.map(\.count).max() ?? 0)
        if headers.count < maxColumns {
            headers += (headers.count..<maxColumns).map { "열\($0 + 1)" }
        }
        var lines = ["### 표 \(index)", ""]
        lines.append(markdownTableRow(headers))
        lines.append(markdownTableRow(Array(repeating: "---", count: headers.count)))
        for row in table.dropFirst() {
            lines.append(markdownTableRow(padRow(row.map { singleLine($0) }, to: headers.count)))
        }
        return lines.joined(separator: "\n")
    }

    private static func expandedRow(
        _ row: Row,
        sharedStrings: SharedStrings?,
        warnings: inout [DocumentIngestionWarning]
    ) -> [String] {
        let sortedCells = row.cells.sorted { cellA, cellB in
            columnIndex(for: cellA) < columnIndex(for: cellB)
        }

        var values: [String] = []
        var currentColumn = 1

        for cell in sortedCells {
            let column = columnIndex(for: cell)
            if column > currentColumn {
                let paddingCount = column - currentColumn
                values += Array(repeating: "", count: paddingCount)
                if paddingCount > 0 {
                    warnings.append(.sparseSheetCompacted)
                }
            }

            values.append(stringValue(for: cell, sharedStrings: sharedStrings))
            currentColumn = column + 1

            if values.count >= maxXLSXCellsPerRow {
                warnings.append(.cellLimitReached)
                break
            }
        }

        return values
    }

    private static func stringValue(for cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings, let value = cell.stringValue(sharedStrings)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return singleLine(value)
        }
        if let inline = cell.inlineString?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !inline.isEmpty {
            return singleLine(inline)
        }
        if let value = cell.value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return singleLine(value)
        }
        if let date = cell.dateValue {
            return singleLine(dateFormatter.string(from: date))
        }
        return ""
    }

    private static func columnIndex(for cell: Cell) -> Int {
        let reference = String(describing: cell.reference)
        let letters = reference.prefix { $0.isLetter }
        guard !letters.isEmpty else { return 1 }

        var result = 0
        for scalar in letters.uppercased().unicodeScalars {
            result = (result * 26) + Int(scalar.value) - 64
        }
        return max(result, 1)
    }

    private static func sanitizeHeaderRow(_ row: [String]) -> [String] {
        guard !row.isEmpty else { return [] }
        var hasMeaningfulHeaders = false
        let headers = row.enumerated().map { index, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "열\(index + 1)"
            }
            hasMeaningfulHeaders = true
            return trimmed
        }
        return hasMeaningfulHeaders ? headers : row.indices.map { "열\($0 + 1)" }
    }

    private static func padRow(_ row: [String], to count: Int) -> [String] {
        if row.count >= count {
            return Array(row.prefix(count))
        }
        return row + Array(repeating: "", count: count - row.count)
    }

    private static func markdownTableRow(_ cells: [String]) -> String {
        let escaped = cells.map { cell in
            cell
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "|", with: "\\|")
        }
        return "| " + escaped.joined(separator: " | ") + " |"
    }

    private static func normalizedParagraphs(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    fileprivate static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func archiveEntries(at url: URL) throws -> [String: Data] {
        let archive = try Archive(url: url, accessMode: .read)

        var entries: [String: Data] = [:]
        for entry in archive {
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            entries[entry.path] = data
        }
        return entries
    }

    private static func docxHeaderFooterSections(from entries: [String: Data]) -> String {
        let relTargets = ooxmlRelationshipTargets(xmlData: entries["word/_rels/document.xml.rels"])
        let relevantTargets = relTargets.values
            .filter { $0.hasPrefix("header") || $0.hasPrefix("footer") }
            .map { "word/\($0)" }
            .sorted()

        var sections: [String] = []
        for path in relevantTargets {
            guard let data = entries[path], let parsed = DOCXBodyParser().parse(data: data) else { continue }
            let label = path.contains("header") ? "머리말" : "꼬리말"
            let content = parsed.blocks.compactMap { block -> String? in
                switch block {
                case .paragraph(let paragraph):
                    return paragraph.text.isEmpty ? nil : paragraph.text
                case .table:
                    return nil
                }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                sections.append("### \(label)\n\n\(content)")
            }
        }
        return sections.joined(separator: "\n\n")
    }

    private static func pptxNotesTexts(slidePath: String, entries: [String: Data]) -> [String] {
        let relsPath = slideRelationshipsPath(for: slidePath)
        let relTargets = ooxmlRelationshipTargets(xmlData: entries[relsPath])
        guard let notesTarget = relTargets.values.first(where: { $0.contains("notesSlide") }) else {
            return []
        }
        let notesPath = normalizedOOXMLPath(target: notesTarget, relativeTo: slidePath)
        guard let notesData = entries[notesPath] else { return [] }
        return PPTXNotesParser().parse(data: notesData)
    }

    private static func slideRelationshipsPath(for slidePath: String) -> String {
        let components = slidePath.split(separator: "/").map(String.init)
        guard let filename = components.last else { return slidePath }
        let dir = components.dropLast().joined(separator: "/")
        return "\(dir)/_rels/\(filename).rels"
    }

    private static func ooxmlRelationshipTargets(xmlData: Data?) -> [String: String] {
        guard let xmlData, let xml = String(data: xmlData, encoding: .utf8) else { return [:] }
        let pattern = #"Relationship[^>]*Id="([^"]+)"[^>]*Target="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let nsRange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        var targets: [String: String] = [:]
        for match in regex.matches(in: xml, range: nsRange) {
            guard
                let idRange = Range(match.range(at: 1), in: xml),
                let targetRange = Range(match.range(at: 2), in: xml)
            else { continue }
            targets[String(xml[idRange])] = String(xml[targetRange])
        }
        return targets
    }

    private static func normalizedOOXMLPath(target: String, relativeTo sourcePath: String) -> String {
        if target.hasPrefix("/") {
            return String(target.dropFirst())
        }
        let baseComponents = sourcePath.split(separator: "/").dropLast().map(String.init)
        var components = baseComponents
        for part in target.split(separator: "/").map(String.init) {
            switch part {
            case ".":
                continue
            case "..":
                if !components.isEmpty {
                    components.removeLast()
                }
            default:
                components.append(part)
            }
        }
        return components.joined(separator: "/")
    }

    private static func slideNumber(from path: String) -> Int {
        let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let digits = filename.replacingOccurrences(of: "slide", with: "")
        return Int(digits) ?? .max
    }

    private static func deduplicated(_ warnings: [DocumentIngestionWarning]) -> [DocumentIngestionWarning] {
        var seen: Set<DocumentIngestionWarning> = []
        return warnings.filter { seen.insert($0).inserted }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private final class DOCXBodyParser: NSObject, XMLParserDelegate {
    struct Paragraph {
        let text: String
        let isListItem: Bool
        let listLevel: Int
    }

    enum Block {
        case paragraph(Paragraph)
        case table([[String]])
    }

    struct Result {
        let blocks: [Block]
        let paragraphCount: Int
        let tableCount: Int
    }

    private var blocks: [Block] = []
    private var paragraphCount = 0
    private var tableCount = 0
    private var isInsideText = false
    private var isInsideTable = false
    private var isInsideParagraphProperties = false
    private var currentParagraphIsList = false
    private var currentParagraphListLevel = 0
    private var currentParagraph = ""
    private var currentCell = ""
    private var currentRow: [String] = []
    private var currentTable: [[String]] = []

    func parse(data: Data) -> Result? {
        blocks = []
        paragraphCount = 0
        tableCount = 0
        isInsideText = false
        isInsideTable = false
        isInsideParagraphProperties = false
        currentParagraphIsList = false
        currentParagraphListLevel = 0
        currentParagraph = ""
        currentCell = ""
        currentRow = []
        currentTable = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }

        return Result(blocks: blocks, paragraphCount: paragraphCount, tableCount: tableCount)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = qName ?? elementName
        switch name {
        case "w:tbl":
            isInsideTable = true
            currentTable = []
        case "w:p":
            currentParagraph = ""
            currentParagraphIsList = false
            currentParagraphListLevel = 0
        case "w:pPr":
            isInsideParagraphProperties = true
        case "w:pStyle":
            if let style = attributeDict["w:val"]?.lowercased(), style.contains("list") {
                currentParagraphIsList = true
            }
        case "w:numPr":
            currentParagraphIsList = true
        case "w:ilvl":
            if let rawLevel = attributeDict["w:val"], let level = Int(rawLevel) {
                currentParagraphListLevel = level
            }
        case "w:tr":
            currentRow = []
        case "w:tc":
            currentCell = ""
        case "w:t":
            isInsideText = true
        case "w:tab":
            appendText(" ")
        case "w:br":
            appendText("\n")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideText else { return }
        appendText(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        switch name {
        case "w:t":
            isInsideText = false
        case "w:pPr":
            isInsideParagraphProperties = false
        case "w:p":
            if isInsideTable {
                if !currentCell.hasSuffix("\n") {
                    currentCell.append("\n")
                }
            } else {
                let text = FileIntakeService.singleLine(currentParagraph)
                if !text.isEmpty {
                    blocks.append(.paragraph(.init(
                        text: text,
                        isListItem: currentParagraphIsList,
                        listLevel: currentParagraphListLevel
                    )))
                    paragraphCount += 1
                }
                currentParagraph = ""
                currentParagraphIsList = false
                currentParagraphListLevel = 0
            }
        case "w:tc":
            currentRow.append(FileIntakeService.singleLine(currentCell))
            currentCell = ""
        case "w:tr":
            if currentRow.contains(where: { !$0.isEmpty }) {
                currentTable.append(currentRow)
            }
            currentRow = []
        case "w:tbl":
            if !currentTable.isEmpty {
                blocks.append(.table(currentTable))
                tableCount += 1
            }
            currentTable = []
            isInsideTable = false
        default:
            break
        }
    }

    private func appendText(_ text: String) {
        if isInsideTable {
            currentCell.append(text)
        } else {
            currentParagraph.append(text)
        }
    }
}

private final class PPTXSlideParser: NSObject, XMLParserDelegate {
    struct Result {
        let texts: [String]
        let tables: [[[String]]]
    }

    private var texts: [String] = []
    private var isInsideText = false
    private var currentText = ""
    private var isInsideTable = false
    private var currentTable: [[String]] = []
    private var currentRow: [String] = []
    private var currentCell = ""
    private var tables: [[[String]]] = []

    func parse(data: Data) -> Result {
        texts = []
        isInsideText = false
        currentText = ""
        isInsideTable = false
        currentTable = []
        currentRow = []
        currentCell = ""
        tables = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        _ = parser.parse()
        return Result(texts: texts, tables: tables)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = qName ?? elementName
        switch name {
        case "a:tbl":
            isInsideTable = true
            currentTable = []
        case "a:tr":
            currentRow = []
        case "a:tc":
            currentCell = ""
        case "a:t":
            isInsideText = true
            currentText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideText else { return }
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        switch name {
        case "a:t":
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                if isInsideTable {
                    currentCell.append(text)
                } else {
                    texts.append(text)
                }
            }
            isInsideText = false
            currentText = ""
        case "a:tc":
            currentRow.append(currentCell)
            currentCell = ""
        case "a:tr":
            if currentRow.contains(where: { !$0.isEmpty }) {
                currentTable.append(currentRow)
            }
            currentRow = []
        case "a:tbl":
            if !currentTable.isEmpty {
                tables.append(currentTable)
            }
            currentTable = []
            isInsideTable = false
        default:
            break
        }
    }
}

private final class PPTXNotesParser: NSObject, XMLParserDelegate {
    private var texts: [String] = []
    private var isInsideText = false
    private var currentText = ""

    func parse(data: Data) -> [String] {
        texts = []
        isInsideText = false
        currentText = ""

        let parser = XMLParser(data: data)
        parser.delegate = self
        _ = parser.parse()
        return texts
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = qName ?? elementName
        if name == "a:t" {
            isInsideText = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideText else { return }
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        if name == "a:t" {
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                texts.append(text)
            }
            isInsideText = false
            currentText = ""
        }
    }
}
