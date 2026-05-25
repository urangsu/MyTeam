import Foundation
import PDFKit

struct PDFPage: Sendable {
    let pageNumber: Int
    let text: String
    let height: CGFloat
    let width: CGFloat
}

enum PDFExtractionError: LocalizedError, Sendable {
    case invalidPDF
    case noTextFound
    case encryptedPDF
    case unsupportedVersion
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "PDF 파일이 손상되었습니다"
        case .noTextFound:
            return "이 PDF에는 추출 가능한 텍스트가 없습니다"
        case .encryptedPDF:
            return "암호화된 PDF는 열 수 없습니다"
        case .unsupportedVersion:
            return "지원하지 않는 PDF 버전입니다"
        case .extractionFailed(let detail):
            return "PDF 텍스트 추출 실패: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noTextFound:
            return "스캔된 이미지 PDF일 수 있습니다. OCR 도구를 사용해보세요."
        case .encryptedPDF:
            return "암호 없이 열 수 있는 PDF로 변환한 후 다시 시도하세요."
        default:
            return nil
        }
    }
}

enum PDFFileExtractor {
    static func extractText(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw PDFExtractionError.invalidPDF
        }

        if pdf.isEncrypted {
            throw PDFExtractionError.encryptedPDF
        }

        var fullText = ""
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            if let text = page.string {
                fullText += text + "\n"
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDFExtractionError.noTextFound
        }

        return fullText
    }

    static func extractMarkdown(from url: URL) throws -> String {
        let pages = try extractPages(from: url)
        let markdown = pages.map { pageToMarkdown($0) }.joined(separator: "\n\n---\n\n")
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractPages(from url: URL) throws -> [PDFPage] {
        guard let pdf = PDFDocument(url: url) else {
            throw PDFExtractionError.invalidPDF
        }

        if pdf.isEncrypted {
            throw PDFExtractionError.encryptedPDF
        }

        var pages: [PDFPage] = []
        for i in 0..<pdf.pageCount {
            guard let pdfPage = pdf.page(at: i) else { continue }

            let text = pdfPage.string ?? ""
            let bounds = pdfPage.bounds(for: .mediaBox)

            pages.append(PDFPage(
                pageNumber: i + 1,
                text: text,
                height: bounds.height,
                width: bounds.width
            ))
        }

        guard !pages.isEmpty else {
            throw PDFExtractionError.noTextFound
        }

        return pages
    }

    private static func pageToMarkdown(_ page: PDFPage) -> String {
        let lines = page.text.components(separatedBy: .newlines)
        var markdownLines: [String] = []

        if page.pageNumber > 1 {
            markdownLines.append("## Page \(page.pageNumber)")
            markdownLines.append("")
        }

        var currentParagraph: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    markdownLines.append(currentParagraph.joined(separator: " "))
                    markdownLines.append("")
                    currentParagraph = []
                }
            } else {
                currentParagraph.append(trimmed)
            }
        }

        if !currentParagraph.isEmpty {
            markdownLines.append(currentParagraph.joined(separator: " "))
        }

        return markdownLines.joined(separator: "\n")
    }
}
