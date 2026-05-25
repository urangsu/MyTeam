import Foundation
import ZIPFoundation

struct DOCXParagraph: Sendable {
    let text: String
    let isHeading: Bool
}

enum DOCXExtractionError: LocalizedError, Sendable {
    case invalidDOCX
    case noContent
    case invalidXML
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDOCX:
            return "DOCX 파일이 손상되었습니다"
        case .noContent:
            return "이 DOCX 파일에는 콘텐츠가 없습니다"
        case .invalidXML:
            return "DOCX 형식이 잘못되었습니다"
        case .extractionFailed(let detail):
            return "콘텐츠 추출 실패: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noContent:
            return "다른 Word 파일을 시도해보세요."
        case .invalidXML:
            return "Word에서 파일을 다시 저장한 후 시도하세요."
        default:
            return nil
        }
    }
}

enum DOCXFileExtractor {
    static func extractText(from url: URL) throws -> String {
        let paragraphs = try extractParagraphs(from: url)
        guard !paragraphs.isEmpty else {
            throw DOCXExtractionError.noContent
        }
        return paragraphs.map { $0.text }.joined(separator: "\n")
    }

    static func extractMarkdown(from url: URL) throws -> String {
        let paragraphs = try extractParagraphs(from: url)
        guard !paragraphs.isEmpty else {
            throw DOCXExtractionError.noContent
        }

        let markdown = paragraphs.map { para -> String in
            if para.isHeading {
                return "## \(para.text)"
            } else {
                return para.text.isEmpty ? "" : para.text
            }
        }.filter { !$0.isEmpty }.joined(separator: "\n\n")

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractParagraphs(from url: URL) throws -> [DOCXParagraph] {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw DOCXExtractionError.invalidDOCX
        }

        guard let contentEntry = archive["word/document.xml"] else {
            throw DOCXExtractionError.noContent
        }

        var data = Data()
        _ = try archive.extract(contentEntry, consumer: { chunk in
            data.append(chunk)
        })

        let paragraphs = try parseDocument(data)
        guard !paragraphs.isEmpty else {
            throw DOCXExtractionError.noContent
        }

        return paragraphs
    }

    private static func parseDocument(_ data: Data) throws -> [DOCXParagraph] {
        var paragraphs: [DOCXParagraph] = []

        let parser = XMLParser(data: data)

        class DocumentParserDelegate: NSObject, XMLParserDelegate {
            var paragraphs: [DOCXParagraph] = []
            var currentText = ""
            var inParagraph = false
            var inRunText = false
            var isHeading = false
            var inStyleTag = false
            var currentStyle = ""

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "p" || elementName == "w:p" {
                    inParagraph = true
                    currentText = ""
                    isHeading = false
                    currentStyle = ""
                } else if (elementName == "t" || elementName == "w:t") && inParagraph {
                    inRunText = true
                } else if elementName == "pStyle" || elementName == "w:pStyle" {
                    inStyleTag = true
                    if let val = attributeDict["w:val"] ?? attributeDict["val"] {
                        currentStyle = val
                        isHeading = val.lowercased().contains("heading")
                    }
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if inRunText {
                    currentText += string
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "t" || elementName == "w:t" {
                    inRunText = false
                } else if elementName == "p" || elementName == "w:p" {
                    inParagraph = false
                    let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty {
                        paragraphs.append(DOCXParagraph(text: trimmedText, isHeading: isHeading))
                    }
                }
            }
        }

        let delegate = DocumentParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            throw DOCXExtractionError.invalidXML
        }

        return delegate.paragraphs
    }
}
