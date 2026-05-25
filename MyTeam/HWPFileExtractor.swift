import Foundation
import ZIPFoundation

// MARK: - HWPParagraph

struct HWPParagraph: Sendable {
    let style: String?
    let text: String
    let isListItem: Bool
}

// MARK: - HWPExtractionError

enum HWPExtractionError: LocalizedError, Sendable {
    case invalidZipArchive
    case missingContentXML
    case invalidXMLFormat
    case encodingError
    case unsupportedHWPVersion

    var errorDescription: String? {
        switch self {
        case .invalidZipArchive:
            return "HWP 파일이 손상되었거나 ZIP 형식이 아닙니다."
        case .missingContentXML:
            return "HWP 파일에서 content.xml을 찾을 수 없습니다."
        case .invalidXMLFormat:
            return "HWP 파일의 XML 형식이 잘못되었습니다."
        case .encodingError:
            return "파일 인코딩을 처리할 수 없습니다."
        case .unsupportedHWPVersion:
            return "지원하지 않는 HWP 버전입니다."
        }
    }
}

// MARK: - HWPFileExtractor

enum HWPFileExtractor {

    /// HWP 파일에서 텍스트 추출
    /// - Parameter url: HWP/HWPX 파일 URL
    /// - Returns: 추출된 텍스트 (한 문단당 한 줄)
    static func extractText(from url: URL) throws -> String {
        let paragraphs = try extractParagraphs(from: url)
        return paragraphs
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    /// HWP 파일에서 마크다운 추출
    /// - Parameter url: HWP/HWPX 파일 URL
    /// - Returns: 마크다운 형식 텍스트
    static func extractMarkdown(from url: URL) throws -> String {
        let paragraphs = try extractParagraphs(from: url)
        return paragraphs.map { para in
            let trimmed = para.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }

            // 스타일별 마크다운 변환
            if let style = para.style {
                if style.contains("Heading1") || style.contains("제목1") {
                    return "## \(trimmed)"
                } else if style.contains("Heading2") || style.contains("제목2") {
                    return "### \(trimmed)"
                } else if style.contains("Heading3") || style.contains("제목3") {
                    return "#### \(trimmed)"
                }
            }

            // 목록 항목
            if para.isListItem {
                return "- \(trimmed)"
            }

            // 일반 본문
            return trimmed
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    /// HWP 파일에서 단락 배열 추출
    /// - Parameter url: HWP/HWPX 파일 URL
    /// - Returns: 단락 정보 배열
    private static func extractParagraphs(from url: URL) throws -> [HWPParagraph] {
        let entries = try unpackArchive(at: url)

        guard let contentData = entries["content.xml"] else {
            throw HWPExtractionError.missingContentXML
        }

        let paragraphs = try parseContentXML(contentData)
        return paragraphs
    }

    /// content.xml 파싱 (XML 기반)
    /// - Parameter data: content.xml 데이터
    /// - Returns: 추출된 단락 배열
    private static func parseContentXML(_ data: Data) throws -> [HWPParagraph] {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw HWPExtractionError.encodingError
        }

        var paragraphs: [HWPParagraph] = []
        let parser = HWPXMLParser(xmlString: xmlString)

        do {
            paragraphs = try parser.parse()
        } catch {
            throw HWPExtractionError.invalidXMLFormat
        }

        return paragraphs
    }

    /// ZIP 파일 언팩
    /// - Parameter url: HWP/HWPX 파일 URL
    /// - Returns: 파일명 → 데이터 딕셔너리
    private static func unpackArchive(at url: URL) throws -> [String: Data] {
        var entries: [String: Data] = [:]

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw HWPExtractionError.invalidZipArchive
        }

        do {
            if let archive = Archive(url: url, accessMode: .read) {
                for entry in archive {
                    var entryData = Data()
                    _ = try archive.extract(entry) { chunk in
                        entryData.append(chunk)
                    }
                    entries[entry.path] = entryData
                }
            }
        } catch {
            throw HWPExtractionError.invalidZipArchive
        }

        return entries
    }
}

// MARK: - HWPXMLParser (단순 텍스트 추출)

private final class HWPXMLParser: NSObject, XMLParserDelegate {
    private let xmlString: String
    private var currentText = ""
    private var currentStyle: String?
    private var isListItem = false
    private var paragraphs: [HWPParagraph] = []
    private var parsingError: Error?

    init(xmlString: String) {
        self.xmlString = xmlString
    }

    func parse() throws -> [HWPParagraph] {
        guard let data = xmlString.data(using: .utf8) else {
            throw HWPExtractionError.encodingError
        }

        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            return paragraphs
        } else {
            throw parsingError ?? HWPExtractionError.invalidXMLFormat
        }
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "p:paragraph", "paragraph":
            currentText = ""
            currentStyle = attributeDict["p:style"] ?? attributeDict["style"]
            isListItem = attributeDict["p:listLevel"] != nil

        case "p:text", "text":
            currentText = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "p:paragraph", "paragraph":
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let para = HWPParagraph(
                    style: currentStyle,
                    text: trimmed,
                    isListItem: isListItem
                )
                paragraphs.append(para)
            }
            currentText = ""
            currentStyle = nil
            isListItem = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: NSError) {
        parsingError = parseError
    }
}
